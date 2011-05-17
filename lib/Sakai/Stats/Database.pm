#!/usr/bin/perl -w

package Sakai::Stats::Database;

use 5.008001;
use strict;
use warnings;
use Carp;
use DBI;
use DBD::mysql;

require Exporter;

use base qw(Exporter);

our @EXPORT_OK = ();

our $VERSION = '0.02';

#{{{sub new

sub new {
    my ( $class, $stats ) = @_;
    if ( !defined $stats ) { croak 'no stats object provided!'; }
    my $dsn;
    my $conn;
    my $queryhandle;
    my $database = {
        Conn        => $conn,
        DSN         => $dsn,
        QueryHandle => $queryhandle,
        Stats       => $stats,
    };
    bless $database, $class;
    return $database;
}

#}}}

#{{{sub connect

sub make_connection {
    my ($database) = @_;
    $database->{'DSN'} =
        q{dbi:} 
      . q{mysql} . q{:}
      . ${ $database->{'Stats'} }->{'DBName'} . q{:}
      . ${ $database->{'Stats'} }->{'DBHost'} . q{:}
      . ${ $database->{'Stats'} }->{'DBPort'};
    $database->{'Conn'} = DBI->connect(
        $database->{'DSN'},
        ${ $database->{'Stats'} }->{'DBUser'},
        ${ $database->{'Stats'} }->{'DBPass'}
    ) || croak 'Problem accessing stats database';
    return 1;
}

#}}}

#{{{sub inst_users_per_month

sub inst_users_per_month {
    my ( $database, $year, $month ) = @_;
    my $query =
        q{select SESSION_USER FROM SAKAI_SESSION WHERE SESSION_START LIKE '}
      . $year . q{-}
      . $month . q{%'};
    $database->{'QueryHandle'} = $database->{'Conn'}->prepare($query);
    $database->{'QueryHandle'}->execute();
    return 1;
}

#}}}

1;

__END__

=head1 NAME

Sakai::Stats::Database

=head1 ABSTRACT

Library that provides a layer of abstraction to statistical data stored in the database.

=head1 METHODS

=head2 new

Create, set up, and return a Database object.

=head1 USAGE

use Sakai::Stats::Database;

=head1 DESCRIPTION

Library to provide a layer of abstraction to statistical data stored in the database

=head1 REQUIRED ARGUMENTS

None required.

=head1 OPTIONS

n/a

=head1 DIAGNOSTICS

n/a

=head1 EXIT STATUS

0 on success.

=head1 CONFIGURATION

None required.

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known.

=head1 AUTHOR

Daniel David Parry <perl@ddp.me.uk>

=head1 LICENSE AND COPYRIGHT

LICENSE: http://dev.perl.org/licenses/artistic.html

COPYRIGHT: (c) 2011 Daniel David Parry <perl@ddp.me.uk>
