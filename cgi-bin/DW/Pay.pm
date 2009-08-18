#!/usr/bin/perl
#
# DW::Pay
#
# Core of the payment system.
#
# Authors:
#      Mark Smith <mark@dreamwidth.org>
#
# Copyright (c) 2008-2009 by Dreamwidth Studios, LLC.
#
# This program is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself.  For a copy of the license, please reference
# 'perldoc perlartistic' or 'perldoc perlgpl'.
#

package DW::Pay;

use strict;

use Carp qw/ confess /;
use HTTP::Request;
use LWP::UserAgent;

our $error_code = undef;
our $error_text = undef;

use constant ERR_FATAL => 1;
use constant ERR_TEMP => 2;

################################################################################
# DW::Pay::type_is_valid
#
# ARGUMENTS: typeid
#
#   typeid      required    the id of the type we're checking
#
# RETURN: 1/0 if the type is a valid type
#
sub type_is_valid {
    return 1 if $LJ::CAP{$_[0]} && $LJ::CAP{$_[0]}->{_account_type};
    return 0;
}

################################################################################
# DW::Pay::type_name
#
# ARGUMENTS: typeid
#
#   typeid      required    the id of the type we're checking
#
# RETURN: string name of type, else undef
#
sub type_name {
    confess 'invalid typeid'
        unless DW::Pay::type_is_valid( $_[0] );
    return $LJ::CAP{$_[0]}->{_visible_name};
}

################################################################################
# DW::Pay::get_paid_status
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to get paid status of
#
# RETURN: Hashref if paid (or has ever been), undef if free:
#
#   {
#       typeid => ...
#       expiretime => db time epoch seconds they expire at
#       expiresin => seconds until they expire
#       permanent => 1/0 if they're permanent
#   }
#
sub get_paid_status {
    DW::Pay::clear_error();

    my $uuid = shift;

    my $uid = LJ::want_userid($uuid) if defined $uuid;
    return error( ERR_FATAL, "Invalid user object/userid passed in." )
        unless defined $uid && $uid > 0;

    my $dbr = DW::Pay::get_db_reader()
        or return error( ERR_TEMP, "Failed acquiring database reader handle." );
    my $row = $dbr->selectrow_hashref( q{
            SELECT IFNULL(expiretime, 0) - UNIX_TIMESTAMP() AS 'expiresin', typeid, expiretime, permanent
            FROM dw_paidstatus
            WHERE userid = ?
        }, undef, $uid );
    return error( ERR_FATAL, "Database error: " . $dbr->errstr )
        if $dbr->err;

    return $row;
}

################################################################################
# DW::Pay::default_typeid
#
# RETURN: typeid of the default account type.
#
sub default_typeid {
    # try to get the default cap class.  note that we confess here because
    # these errors are bad enough to warrant bailing whoever is calling us.
    my @defaults = grep { $LJ::CAP{$_}->{_account_default} } keys %LJ::CAP;
    confess 'must have one %LJ::CAP class set _account_default to use the payment system'
        if scalar( @defaults ) < 1;
    confess 'only one %LJ::CAP class can be set as _account_default'
        if scalar( @defaults ) > 1;

    # There Can Be Only One
    return $defaults[0];
}

################################################################################
# DW::Pay::get_current_account_status
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to get paid status of
#
# RETURN: undef for free, else a typeid of the account type.
#
sub get_current_account_status {
    # try to get current paid status
    my $stat = DW::Pay::get_paid_status( @_ );

    # free accounts: no row, or expired
    return DW::Pay::default_typeid() unless defined $stat;
    return DW::Pay::default_typeid() unless $stat->{permanent} || $stat->{expiresin} > 0;

    # valid row, return whatever type it is
    return $stat->{typeid};
}

################################################################################
# DW::Pay::get_account_expiration_time
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to get paid status of
#
# RETURN: -1 for free or perm, 0 for expired paid, else the unix timestamp this
#         account expires on...
#
# yes, this function has a very weird return value.  :(
#
sub get_account_expiration_time {
    # try to get current paid status
    my $stat = DW::Pay::get_paid_status( @_ );

    # free accounts: no row, or expired
    # perm accounts: no expiration
    return -1 if !defined $stat || $stat->{permanent};
    return  0 unless $stat->{expiresin} > 0;

    # valid row, return whatever the expiration time is
    return time() + $stat->{expiresin};
}

################################################################################
# DW::Pay::get_account_type
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to get paid status of
#
# RETURN: value defined as _account_type in %LJ::CAP.
#
sub get_account_type {
    my $typeid = DW::Pay::get_current_account_status( @_ );
    confess 'account has no valid typeid'
        unless $typeid && $typeid > 0;
    confess "typeid $typeid not a valid account level"
        unless $LJ::CAP{$typeid} && $LJ::CAP{$typeid}->{_account_type};
    return $LJ::CAP{$typeid}->{_account_type};
}

################################################################################
# DW::Pay::get_account_type_name
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to get paid status of
#
# RETURN: value defined as _visible_name in %LJ::CAP.
#
sub get_account_type_name {
    my $typeid = DW::Pay::get_current_account_status( @_ );
    confess 'account has no valid typeid'
        unless $typeid && $typeid > 0;
    confess "typeid $typeid not a valid account level"
        unless $LJ::CAP{$typeid} && $LJ::CAP{$typeid}->{_visible_name};
    return $LJ::CAP{$typeid}->{_visible_name};
}

################################################################################
# DW::Pay::get_current_paid_userids
#
# ARGUMENTS: limit => #rows, typeid => paid account type, permanent => 0|1
#
#   limit       optional    how many userids to return (default: no limit)
#   typeid      optional    1 to restrict to basic paid, 2 for premium paid
#                           (default: both)
#   permanent   optional    false to restrict to expiring accounts, true to
#                           permanent (default: both)
#
# RETURN: arrayref of userids for currently paid accounts matching the above
#         restrictions
#
sub get_current_paid_userids {
    DW::Pay::clear_error();

    my %opts = @_;

    my $sql = 'SELECT userid FROM dw_paidstatus WHERE ';
    my ( @where, @values );

    if ( exists $opts{permanent} ) {
        push @where, 'permanent = ?';
        push @values, ($opts{permanent} ? 1 : 0);
        push @where, 'expiretime > UNIX_TIMESTAMP(NOW())'
            unless $opts{permanent};
    } else {
        push @where, '(permanent = 1 OR expiretime > UNIX_TIMESTAMP(NOW()))';
    }

    if ( exists $opts{typeid} ) {
        push @where, 'typeid = ?';
        push @values, $opts{typeid};
    }

    $sql .= join ' AND ', @where;

    if ( exists $opts{limit} ) {
        $sql .= ' LIMIT ?';
        push @values, $opts{limit};
    }

    my $dbr = DW::Pay::get_db_reader()
        or return error( ERR_TEMP, "Unable to get db reader." );
    my $uids = $dbr->selectcol_arrayref( $sql, {}, @values );
    return error( ERR_FATAL, "Database error: " . $dbr->errstr )
        if $dbr->err;
    return $uids;
}


################################################################################
# DW::Pay::expire_user
#
# ARGUMENTS: uuserid
#
#   uuserid     required    user object or userid to set paid status for
#
# RETURN: undef on error, else 1 on success.
#
# This is a low level function that expires a user if they need to be.  It's a
# no-op if the user is not supposed to be expired, but don't call it if you know
# that's the case.
#
sub expire_user {
    DW::Pay::clear_error();

    my ( $u, %opts ) = @_;
    $u = LJ::want_user( $u )
        or return error( ERR_FATAL, "Invalid/not a user object." );

    unless ( $opts{force} ) {
        my $ps = DW::Pay::get_paid_status( $u );
        return 1 unless $ps; # free already
        return error( ERR_FATAL, "Cannot expire a permanent account." )
            if $ps->{permanent};
        return error( ERR_FATAL, "Account not ready for expiration." )
            if $ps->{expiresin} > 0;
    }

    # so we have to update their status now
    LJ::statushistory_add( $u, undef, 'paidstatus', 'Expiring account; forced=' . ( $opts{force} ? 1 : 0 ) . '.' );
    DW::Pay::update_paid_status( $u, _expire => 1 );
    DW::Pay::sync_caps( $u );

    # inactivate userpics (yes, this method does inactivation too)
    $u->activate_userpics;

    # disable email alias
    $u->delete_email_alias;

    # happy times
    return 1;
}


################################################################################
# DW::Pay::add_paid_time
#
# ARGUMENTS: uuserid, class, months
#
#   uuserid     required    user object or userid to set paid status for
#   class       required    type of account to be using (_account_type)
#   months      required    how many months to grant, 99 = perm
#
# RETURN: undef on error, else 1 on success.
#
# This is a low level function, you better be logging!
#
sub add_paid_time {
    DW::Pay::clear_error();

    my $u = LJ::want_user( shift() )
        or return error( ERR_FATAL, "Invalid/not a user object." );

    my $type = shift();
    my ($typeid) = grep { $LJ::CAP{$_}->{_account_type} eq $type } keys %LJ::CAP;
    return error( ERR_FATAL, 'Invalid type, no typeid found.' )
        unless $typeid;

    my $months = shift();
    return error( ERR_FATAL, 'Invalid value for months.' )
        unless $months > 0 && $months <= 12 || $months == 99;

    # okay, let's see what the user is right now to decide what to do
    my ( $newtypeid, $amonths, $asecs ) = ( $typeid, $months, 0 );
    my $permanent = $months == 99 ? 1 : 0;

    # if they have a $ps hashref, they have or had paid time at some point
    if ( my $ps = DW::Pay::get_paid_status( $u ) ) {
        # easy bail if they're permanent
        return error( ERR_FATAL, 'User is already permanent, cannot apply more time.' )
            if $ps->{permanent};

        # not permanent, but do they have at least a minute left?
        if ( $ps->{expiresin} > 60 ) {

            # if it's the same type as what we've got, we just carry it forward by
            # however much time they have left
            if ( $ps->{typeid} == $typeid ) {
                $asecs = $ps->{expiresin};

            # but if they're going permanent...
            } elsif ( $permanent ) {
                $amonths = 0;

            # but the types are different...
            } else {
                # FIXME: this needs to not be dw-nonfree logic
                my $from_type = $LJ::CAP{$ps->{typeid}}->{_account_type};
                my $to_type = $LJ::CAP{$typeid}->{_account_type};

                # paid->premium, we convert at a rate of 0.7
                if ( $from_type eq 'paid' && $to_type eq 'premium' ) {
                    $asecs = int( $ps->{expiresin} * 0.7 );

                # premium->paid, upgrade the new buy to premium.  we give them 21.28
                # days of premium time for every month of paid time they were buying.
                } elsif ( $from_type eq 'premium' && $to_type eq 'paid' ) {
                    $newtypeid = $ps->{typeid};
                    $asecs = $ps->{expiresin} + ( $amonths * 21 * 86400 );
                    $amonths = 0;

                } else {
                    return error( ERR_FATAL, 'Invalid conversion.' )
                }
            }
        }

        # at this point we can ignore whatever they have in $ps, as we're going
        # overwrite it with our own stuff
    }

    # so at this point, we can do whatever we're supposed to do
    my $rv = DW::Pay::update_paid_status( $u,
        typeid => $newtypeid,
        permanent => $permanent,
        _set_months => $amonths,
        _add_secs => $asecs,
    );

    # and make sure caps are always in sync
    DW::Pay::sync_caps( $u )
        if $rv;

    # activate userpics
    $u->activate_userpics;

    # enable email alias
    $u->update_email_alias;

    # all good, we hope :-)
    return $rv;
}


################################################################################
# DW::Pay::update_paid_status
#
# ARGUMENTS: uuserid, key => value pairs
#
#   uuserid     required    user object or userid to set paid status for
#   key         required    column being set
#   value       required    new value to set column to
#
# RETURN: undef on error, else 1 on success.
#
# NOTE: this function is a low level function intended to be use for admin
# pages and similar functionality.  don't use this willy-nilly in anything
# else as it is probably not what you want!
#
# NOTE: you can set special keys if you want to extend time by months, use
# _set_months to set expiretime to now + N months, and _add_months to append
# that many months.  This is more than likely only useful for such things as
# admin tools.  You may also specify _add_secs if you really want to dig in
# and get an exact expiration time.
#
sub update_paid_status {
    DW::Pay::clear_error();

    my $u = LJ::want_user( shift() )
        or return error( ERR_FATAL, "Invalid/not a user object." );
    my %cols = ( @_ )
        or return error( ERR_FATAL, "Nothing to change!" );

    my $dbh = DW::Pay::get_db_writer()
        or return error( ERR_TEMP, "Unable to get db writer." );

    # don't let them add months if the user expired, convert it to set months
    if ( $cols{_add_months} ) {
        my $row = DW::Pay::get_paid_status( $u );
        if ( $row && $row->{expiresin} > 0 ) {
            my $time = $dbh->selectrow_array( "SELECT UNIX_TIMESTAMP(DATE_ADD(FROM_UNIXTIME($row->{expiretime}), " .
                                              "INTERVAL $cols{_add_months} MONTH))" );
            $cols{expiretime} = $time;
            delete $cols{_add_months};

        } else {
            $cols{_set_months} = delete $cols{_add_months};
        }
    }

    if ( exists $cols{_set_months} ) {
        $cols{expiretime} = $dbh->selectrow_array( "SELECT UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL $cols{_set_months} MONTH))" );
        delete $cols{_set_months};
    }

    if ( exists $cols{_add_secs} ) {
        $cols{expiretime} += delete $cols{_add_secs};
    }

    return error( ERR_FATAL, "Can't change the userid!" )
        if exists $cols{userid};
    return error( ERR_FATAL, "Permanent must be 0/1." )
        if exists $cols{permanent} && $cols{permanent} !~ /^(?:0|1)$/;
    return error( ERR_FATAL, "Typeid must be some number and valid." )
        if exists $cols{typeid} && !( $cols{typeid} =~ /^(?:\d+)$/ && DW::Pay::type_is_valid( $cols{typeid} ) );
    return error( ERR_FATAL, "Expiretime must be some number." )
        if exists $cols{expiretime} && $cols{expiretime} !~ /^(?:\d+)$/;
    return error( ERR_FATAL, "Lastemail must be 0, 3, or 14." )
        if exists $cols{lastemail} && defined $cols{lastemail} && $cols{lastemail} !~ /^(?:0|3|14)$/;

    if ( delete $cols{_expire} ) {
        $cols{typeid} = DW::Pay::default_typeid();
        $cols{lastemail} = undef;
        $cols{expiretime} = undef;
        $cols{permanent} = 0; # has to be!
    }

    my $cols = join( ', ', map { "$_ = ?" } sort keys %cols );
    my @bind = map { $cols{$_} } sort keys %cols;

    my $ct = $dbh->do( qq{
            UPDATE dw_paidstatus SET $cols WHERE userid = ?
        }, undef, @bind, $u->id );
    return error( ERR_FATAL, "Database error: " . $dbh->errstr )
        if $dbh->err;

    # if we got 0 rows edited, we have to insert a new row
    if ( $ct == 0 ) {
        # fail if we don't have some valid values
        return error( ERR_FATAL, "Typeid must be some number and valid." )
            unless $cols{typeid} =~ /^(?:\d+)$/ && DW::Pay::type_is_valid( $cols{typeid} );

        # now try the insert
        $dbh->do(
            q{INSERT INTO dw_paidstatus (userid, typeid, expiretime, permanent, lastemail)
              VALUES (?, ?, ?, ?, ?)},
            undef, $u->id, $cols{typeid}, $cols{expiretime}, $cols{permanent}+0, $cols{lastemail}
        );
        return error( ERR_FATAL, "Database error: " . $dbh->errstr )
            if $dbh->err;
    }

    # and now, at this last step, we kick off a job to check if this user
    # needs to have their search index setup/messed with.
    if ( @LJ::SPHINX_SEARCHD && ( my $sclient = LJ::theschwartz() ) ) {
        $sclient->insert_jobs( TheSchwartz::Job->new_from_array( 'DW::Worker::Sphinx::Copier', { userid => $u->id } ) );
    }

    return 1;
}

################################################################################
# DW::Pay::num_permanent_accounts_available
#
# ARGUMENTS: none
#
# RETURN: number of permanent accounts that are still available for purchase
#         -1 if there is no limit on how many permanent accounts can be
#         purchased
#
sub num_permanent_accounts_available {
    DW::Pay::clear_error();

    return 0 unless $LJ::PERMANENT_ACCOUNT_LIMIT;
    return -1 if $LJ::PERMANENT_ACCOUNT_LIMIT < 0;

    # 1. figure out how many permanent accounts have been purchased

    # try memcache first
    my $ct = LJ::MemCache::get( 'numpermaccts' );

    unless ( defined $ct ) {
        # not in memcache, so let's hit the database
        # FIXME: add ddlockd so we don't hit the db in waves every 60 seconds
        my $dbh = DW::Pay::get_db_writer()
            or return error( ERR_TEMP, "Unable to get db writer." );
        $ct = $dbh->selectrow_array( 'SELECT COUNT(*) FROM dw_paidstatus WHERE permanent = 1' )+0;
        LJ::MemCache::set( 'numpermaccts', $ct, 60 );
    }

    # 2. figure out how many are left to purchase

    my $num_available = $LJ::PERMANENT_ACCOUNT_LIMIT - $ct;
    return $num_available > 0 ? $num_available : 0;
}

################################################################################
# DW::Pay::num_permanent_accounts_available_estimated
#
# ARGUMENTS: none
#
# RETURN: estimated number of permanent accounts that are still available for
#         purchase
#         -1 if there is no limit on how many permanent accounts can be
#         purchased
#
sub num_permanent_accounts_available_estimated {
    my $num_available = DW::Pay::num_permanent_accounts_available();
    return $num_available if $num_available < 1;

    return 10  if $num_available <= 10;
    return 25  if $num_available <= 25;
    return 50  if $num_available <= 50;
    return 100 if $num_available <= 100;
    return 150 if $num_available <= 150;
    return 200 if $num_available <= 200;
    return 300 if $num_available <= 300;
    return 400 if $num_available <= 400;
    return 500;
}

################################################################################
# DW::Pay::get_random_active_free_user
#
# ARGUMENTS: for_u = user that is requesting the random free user (remote if
#            no user is given)
#
# RETURN: a random active free user that for_u can purchase a paid account for,
#         or undef if there aren't any valid results
#
sub get_random_active_free_user {
    my $for_u = shift || LJ::get_remote();

    my $dbr = LJ::get_db_reader();
    my $rows = $dbr->selectall_arrayref(
        q{SELECT userid, points FROM users_for_paid_accounts
          ORDER BY RAND() LIMIT 10},
        { Slice => {} } );

    my @active_us;
    my $us = LJ::load_userids( map { $_->{userid} } @$rows );
    foreach my $row ( @$rows ) {
        my $userid = $row->{userid};
        my $points = $row->{points};
        my $u = $us->{$userid};

        next unless $u && $u->is_visible && $u->is_personal;
        next if $u->is_paid;
        next unless $u->opt_randompaidgifts;
        next if LJ::sysban_check( 'pay_user', $u->user );
        next if $for_u && $u->equals( $for_u );
        next if $for_u && $u->has_banned( $for_u );

        # each point that a user has gives them an extra chance of being chosen out of the array
        push @active_us, $u;
        if ( $points ) {
            foreach my $point ( 1..$points ) {
                push @active_us, $u;
            }
        }
    }

    return undef unless scalar @active_us;

    my @shuffled_us = List::Util::shuffle( @active_us );

    return $shuffled_us[0];
}

################################################################################
################################################################################
################################################################################

# this internal method takes a user's paid status (which is the accurate record
# of what caps and things a user should have) and then updates their caps.  i.e.,
# this method is used to make the user's actual caps reflect reality.
sub sync_caps {
    my $u = LJ::want_user( shift )
        or return error( ERR_FATAL, "Must provide a user to sync caps for." );
    my $ps = DW::Pay::get_paid_status( $u );

    # calculate list of caps that we care about
    my @bits = grep { $LJ::CAP{$_}->{_account_type} } keys %LJ::CAP;
    my $default = DW::Pay::default_typeid();

    # either they're free, or they expired (not permanent)
    if ( ! $ps || ( ! $ps->{permanent} && $ps->{expiresin} < 0 ) ) {
        # reset back to the default, and turn off all other bits; then set the
        # email count to defined-but-0
        LJ::modify_caps( $u, [ $default ], [ grep { $_ != $default } @bits ] );
        DW::Pay::update_paid_status( $u, lastemail => 0 );

    } else {
        # this is a really bad error we should never have... we can't
        # handle this user
        # FIXME: candidate for email-site-admins
        return error( ERR_FATAL, "Unknown typeid." )
            unless DW::Pay::type_is_valid( $ps->{typeid} );

        # simply modify it to use the typeid specified, as typeids are bits... but
        # turn off any other bits
        LJ::modify_caps( $u, [ $ps->{typeid} ], [ grep { $_ != $ps->{typeid} } @bits ] );
        DW::Pay::update_paid_status( $u, lastemail => undef );
    }

    return 1;
}

sub error {
    $DW::Pay::error_code = $_[0]+0;
    $DW::Pay::error_text = $_[1] || "Unknown error.";
    return undef;
}

sub error_code {
    return $DW::Pay::error_code;
}

sub error_text {
    return $DW::Pay::error_text;
}

sub was_error {
    return defined $DW::Pay::error_code;
}

sub clear_error {
    $DW::Pay::error_code = $DW::Pay::error_text = undef;
}

sub get_db_reader {
    # we always use the master, but perhaps we want to use a specific role for
    # payments later?  so we abstracted this...
    return LJ::get_db_writer();
}

sub get_db_writer {
    return LJ::get_db_writer();
}

1;
