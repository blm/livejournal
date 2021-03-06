#!/usr/bin/perl
#

# to be require'd by modperl.pl

use strict;

package LJ;

use Apache::LiveJournal;
use Apache::CompressClientFixup;
use Apache::BML;
use Apache::SendStats;
use Apache::DebateSuicide;

use Digest::MD5 qw//;
use Text::Wrap ();
use LWP::UserAgent ();
use Storable qw//;
use Time::HiRes ();
use Image::Size ();

use LJ::Portal ();
use LJ::Blob;
use LJ::Captcha;
use LJ::Faq;


use Class::Autouse qw(
                      DateTime
                      DateTime::TimeZone
                      LJ::CProd
                      LJ::OpenID
                      LJ::Location
                      LJ::SpellCheck
                      LJ::TextMessage
                      LJ::ModuleCheck
                      LJ::Widget
                      MogileFS::Client
                      DDLockClient
                      LJ::BetaFeatures
                      LJ::Config
                      );

LJ::Config->load;

# in web context, Class::Autouse will load this, which loads MapUTF8.
# otherwise, we'll rely on the AUTOLOAD in ljlib.pl to load MapUTF8
use Class::Autouse qw(LJ::ConvUTF8);

# other things we generally want to load in web context, but don't need
# in testing context:  (not autoloaded normal ways)
use Class::Autouse qw(
                      MIME::Words
                      );

# Try to load DBI::Profile
BEGIN { $LJ::HAVE_DBI_PROFILE = eval "use DBI::Profile (); 1;" }

use LJ::Lang;
use LJ::Tags;
require "htmlcontrols.pl";
require "weblib.pl";
require "imageconf.pl";
require "propparse.pl";
require "supportlib.pl";
require "supportstatslib.pl";
require "cleanhtml.pl";
require "talklib.pl";
require "ljtodo.pl";
require "ljfeed.pl";
require "ljlinks.pl";
require "emailcheck.pl";
require "ljmemories.pl";
require "ljmail.pl";
require "sysban.pl";
require "synlib.pl";
require "communitylib.pl";
require "schoollib.pl";
require "accountcodes.pl";
require "ljemailgateway-web.pl";
require "customizelib.pl";

# preload site-local libraries, if present:
require "$ENV{'LJHOME'}/cgi-bin/modperl_subs-local.pl"
    if -e "$ENV{'LJHOME'}/cgi-bin/modperl_subs-local.pl";

# defer loading of hooks, better that in the future, the hook loader
# will be smarter and only load in the *.pm files it needs to fulfill
# the hooks to be run
LJ::load_hooks_dir() unless LJ::is_from_test();

$LJ::IMGPREFIX_BAK = $LJ::IMGPREFIX;
$LJ::STATPREFIX_BAK = $LJ::STATPREFIX;
$LJ::USERPICROOT_BAK = $LJ::USERPIC_ROOT;

package LJ::ModPerl;

# pull in a lot of useful stuff before we fork children

sub setup_start {

    # auto-load some stuff before fork (unless this is a test program)
    unless ($0 && $0 =~ m!(^|/)t/!) {
        Storable::thaw(Storable::nfreeze({}));
        foreach my $minifile ("GIF89a", "\x89PNG\x0d\x0a\x1a\x0a", "\xFF\xD8") {
            Image::Size::imgsize(\$minifile);
        }
        DBI->install_driver("mysql");
        LJ::CleanHTML::helper_preload();
        LJ::Portal->load_portal_boxes;
    }

    # set this before we fork
    $LJ::CACHE_CONFIG_MODTIME = (stat("$ENV{'LJHOME'}/cgi-bin/ljconfig.pl"))[9];

    eval { setup_start_local(); };
}

sub setup_restart {
    
    # setup httpd.conf things for the user:
    LJ::Request->add_httpd_conf("DocumentRoot $LJ::HTDOCS")
        if $LJ::HTDOCS;
    LJ::Request->add_httpd_conf("ServerAdmin $LJ::ADMIN_EMAIL")
        if $LJ::ADMIN_EMAIL;

    LJ::Request->add_httpd_conf(qq{


# This interferes with LJ's /~user URI, depending on the module order
<IfModule mod_userdir.c>
  UserDir disabled
</IfModule>

PerlInitHandler Apache::LiveJournal
PerlInitHandler Apache::SendStats
PerlFixupHandler Apache::CompressClientFixup
PerlCleanupHandler Apache::SendStats
PerlChildInitHandler Apache::SendStats
DirectoryIndex index.html index.bml
});

    # setup child init handler to seed random using a good entropy source
    LJ::Request->push_handlers_global(PerlChildInitHandler => sub {
        srand(LJ::urandom_int());
    });

    if ($LJ::BML_DENY_CONFIG) {
        LJ::Request->add_httpd_conf("PerlSetVar BML_denyconfig \"$LJ::BML_DENY_CONFIG\"\n");
    }

    unless ($LJ::SERVER_TOTALLY_DOWN)
    {
        if (LJ::Request->interface_name eq 'Apache2'){
            LJ::Request->add_httpd_conf(qq{
# BML support:
<Files ~ "\\.bml\$">
  SetHandler perl-script
  PerlResponseHandler Apache::BML
</Files>

});
        } elsif (LJ::Request->interface_name eq 'Apache'){
            LJ::Request->add_httpd_conf(qq{
# BML support:
<Files ~ "\\.bml\$">
  SetHandler perl-script
  PerlHandler Apache::BML
</Files>

});
        }
    }

    #unless ($LJ::DISABLED{ignore_htaccess}) {
    #    LJ::Request->add_httpd_conf(qq{
    #        <Directory "/">
    #            AllowOverride none
    #        </Directory>
    #    });
    #}

    eval { setup_restart_local(); };

}

setup_start();

1;
