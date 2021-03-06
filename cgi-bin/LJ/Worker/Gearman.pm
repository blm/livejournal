package LJ::Worker::Gearman;
use strict;
use lib "$ENV{LJHOME}/cgi-bin";
use Gearman::Worker;
use base "LJ::Worker", "Exporter";
use LJ::WorkerResultStorage;

use LJ;
use vars qw(@EXPORT @EXPORT_OK);
use Getopt::Long qw(:config pass_through);
use IO::Socket::INET ();
use Carp qw(croak);

@EXPORT = qw(gearman_decl gearman_work gearman_set_idle_handler gearman_set_requester_id);

my $worker = Gearman::Worker->new;
my $idle_handler;
my $requester_id; # userid, who requested job, optional

sub gearman_set_requester_id { $requester_id = $_[0]; }

sub gearman_decl {
    my $name = shift;
    my ($subref, $timeout);

    if (ref $_[0] eq 'CODE') {
        $subref = shift;
    } else {
        $timeout = shift;
        $subref = shift;
    }

    $subref = wrapped_verbose($name, $subref) if LJ::Worker::VERBOSE();

    if (defined $timeout) {
        $worker->register_function($name => $timeout => $subref);
    } else {
        $worker->register_function($name => $subref);
    }
}

# set idle handler
sub gearman_set_idle_handler {
    my $cb = shift;
    return unless ref $cb eq 'CODE';
    $idle_handler = $cb;
}

sub gearman_work {
    my %opts = @_;
    my $save_result = delete $opts{save_result} || 0;

    croak "unknown opts passed to gearman_work: " . join(', ', keys %opts)
        if keys %opts;

    if ($LJ::IS_DEV_SERVER) {
        die "DEVSERVER help: No gearmand servers listed in \@LJ::GEARMAN_SERVERS.\n"
            unless @LJ::GEARMAN_SERVERS;
        IO::Socket::INET->new(PeerAddr => $LJ::GEARMAN_SERVERS[0])
            or die "First gearmand server in \@LJ::GEARMAN_SERVERS ($LJ::GEARMAN_SERVERS[0]) isn't responding.\n";
    }

    LJ::Worker->setup_mother();

    # save the results of this worker
    my $storage;

    my $last_death_check = time();

    my $periodic_checks = sub {
        LJ::Worker->check_limits();

        # check to see if we should quit
        $worker->job_servers(@LJ::GEARMAN_SERVERS); # TODO: don't do this everytime, only when config changes?

        exit 0 if LJ::Worker->should_quit;
    };

    my $start_cb = sub {
        my $handle = shift;

        LJ::start_request();
        undef $requester_id;

        # save to db that we are starting the job
        if ($save_result) {
            $storage = LJ::WorkerResultStorage->new(handle => $handle);
            $storage->init_job;
        }
    };

    my $end_work = sub {
        LJ::end_request();
        $periodic_checks->();
    };

    # create callbacks to save job status
    my $complete_cb = sub {
        $end_work->();
        my ($handle, $res) = @_;
        $res ||= '';

        if ($save_result && $storage) {
            my %row = (result   => $res,
                       status   => 'success',
                       end_time => 1);
            $row{userid} = $requester_id if defined $requester_id;
            $storage->save_status(%row);
        }
    };

    my $fail_cb = sub {
        $end_work->();
        my ($handle, $err) = @_;
        $err ||= '';

        if ($save_result && $storage) {
            my %row = (result   => $err,
                       status   => 'error',
                       end_time => 1);
            $row{userid} = $requester_id if defined $requester_id;
            $storage->save_status(%row);
        }

    };

    while (1) {
        $periodic_checks->();
        LJ::Worker::DEBUG("Gearman waiting for work...");

        # do the actual work
        eval {
            $worker->work(
                stop_if     => sub { $_[0] },
                on_complete => $complete_cb,
                on_fail     => $fail_cb,
                on_start    => $start_cb,
            );
        };
        warn $@ if $@;

        if ($idle_handler) {
            LJ::Worker::DEBUG("Gearman idle...");
            eval { 
                LJ::start_request();
                $idle_handler->();
                LJ::end_request();
            };
            warn $@ if $@;
        }
    }
}

# --------------

sub wrapped_verbose {
    my ($name, $subref) = @_;
    return sub {
        warn "  executing '$name'...\n";
        my $ans = eval { $subref->(@_) };
        if ($@) {
            warn "   -> ERR: $@\n";
            die $@; # re-throw
        } elsif (! ref $ans && $ans !~ /^[\0\x7f-\xff]/) {
            my $cleanans = $ans;
            $cleanans =~ s/[^[:print:]]+//g;
            $cleanans = substr($cleanans, 0, 1024) . "..." if length $cleanans > 1024;
            warn "   -> answer: $cleanans\n";
        }
        return $ans;
    };
}

1;
