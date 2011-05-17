#!/usr/bin/perl -w

package Sakai::Stats::Institutions;

use 5.008001;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Text::CSV;
use Net::LDAP;
use FileHandle;

require Exporter;

use base qw(Exporter);

our @EXPORT_OK = ();

our $VERSION = '0.02';

#{{{sub new

sub new {
    my ( $class, $stats ) = @_;
    if ( !defined $stats ) { croak 'no stats object provided!'; }
    my $instid_map;
    my $institution_map;
    my $institutions = {
        Stats          => $stats,
        InstIDMap      => $instid_map,
        InstitutionMap => $institution_map,
    };
    bless $institutions, $class;
    return $institutions;
}

#}}}

#{{{sub perform_search
sub perform_search {
    my ( $institutions, $ldap, $search_string, $attrs, $base ) = @_;

    my $result = $ldap->search(
        base   => "$base",
        scope  => 'sub',
        filter => "$search_string",
        attrs  => $attrs
    )->as_struct;
    return \$result;
}

#}}}

#{{{sub populate_user_insts
sub populate_user_insts {
    my ( $institutions, $institution_map, $result ) = @_;

    # process each DN using it as a key:
    # get an array of the DN names:
    my @array_of_dns = keys %{ ${$result} };

    foreach (@array_of_dns) {
        my $valref = ${$result}->{$_};
        if ( defined $valref->{'uid'} && defined( $valref->{'instid'} ) ) {
            $institution_map->{ @{ $valref->{'uid'} }[0] } =
              $valref->{'instid'};
        }
    }
    return 1;
}

#}}}

#{{{sub populate_inst_names
sub populate_inst_names {
    my ( $institutions, $instid_map, $result ) = @_;

    # process each DN using it as a key:
    # get an array of the DN names:
    my @array_of_dns = keys %{ ${$result} };

    foreach (@array_of_dns) {
        my $valref = ${$result}->{$_};
        if ( defined $valref->{'instid'} && defined( $valref->{'ou'} ) ) {
            $instid_map->{ @{ $valref->{'instid'} }[0] } =
              @{ $valref->{'ou'} }[0];
        }
    }
    return 1;
}

#}}}

#{{{sub ldap_connect
sub ldap_connect {
    my ($institutions) = @_;
    my $ldap = Net::LDAP->new( ${ $institutions->{'Stats'} }->{'LdapHost'} )
      or croak 'Problem connecting to LDAP server!';
    my $mesg = $ldap->bind( version => '3' );
    return $ldap;
}

#}}}

#{{{sub generate_user_insts
sub generate_user_insts {
    my ($institutions) = @_;
    my %institution_map;
    if ( -e ${ $institutions->{'Stats'} }->{'WorkDir'}
        . '/institution_map.dump' )
    {

# A dump of the ldap search already exists, so load in the hash map from the filesystem:
        my $readdump = q{};
        if (
            open my $in,
            '<',
            ${ $institutions->{'Stats'} }->{'WorkDir'} . '/institution_map.dump'
          )
        {
            while (<$in>) { $readdump .= $_; }
            close $in;
        }
        else {
            croak 'problem reading in institution map dump.';
        }
        no strict;
        eval $readdump || croak 'problem with eval';
        %institution_map = %{$institution_map};
        use strict;
    }
    else {

        # We do not have a previously created dump, so retrieve from ldap:
        my $ldap   = $institutions->ldap_connect;
        my $result = $institutions->perform_search(
            $ldap, "(uid=*)",
            [ 'uid', 'instid' ],
            ${ $institutions->{'Stats'} }->{'LdapBase'}
        );
        $institutions->populate_user_insts( \%institution_map, $result );

# Store the institution map on the filesystem, so we don't keep hammering the LDAP server:
        if (
            open my $out,
            '>',
            ${ $institutions->{'Stats'} }->{'WorkDir'} . '/institution_map.dump'
          )
        {
            print {$out} Data::Dumper->Dump( [ \%institution_map ],
                [qw( institution_map )] )
              || croak q(Unable to create dump of institution map!);
            close $out;
        }
        else {
            croak 'problem opening file to dump institution map to.';
        }
    }

# foreach my $v ( keys %institution_map ) {
# print "$v " . @{ $institution_map{$v} }[0] . " (" . @{ $institution_map{$v} } . ")\n";
# }
    $institutions->{'InstitutionMap'} = \%institution_map;
    return 1;
}

#}}}

#{{{sub generate_names_for_ids
sub generate_names_for_ids {
    my ($institutions) = @_;
    my %instid_map;
    if ( -e ${ $institutions->{'Stats'} }->{'WorkDir'} . '/instid_map.dump' ) {

# A dump of the ldap search already exists, so load in the hash map from the filesystem:
        my $readdump = q{};
        if ( open my $in,
            '<',
            ${ $institutions->{'Stats'} }->{'WorkDir'} . '/instid_map.dump' )
        {
            while (<$in>) { $readdump .= $_; }
            close $in;
        }
        else {
            croak 'problem reading in institution map dump.';
        }
        no strict;
        eval $readdump || croak 'problem with eval';
        %instid_map = %{$instid_map};
        use strict;
    }
    else {

        my $ldap   = $institutions->ldap_connect;
        my $result = $institutions->perform_search(
            $ldap, "(instid=*)",
            [ 'ou', 'instid' ],
            ${ $institutions->{'Stats'} }->{'LdapInstBase'}
        );
        $institutions->populate_inst_names( \%instid_map, $result );

# Store the instid map on the filesystem, so we don't keep hammering the LDAP server:
        if ( open my $out,
            '>',
            ${ $institutions->{'Stats'} }->{'WorkDir'} . '/instid_map.dump' )
        {
            print {$out}
              Data::Dumper->Dump( [ \%instid_map ], [qw( instid_map )] )
              || croak q(Unable to create dump of instid map!);
            close $out;
        }
        else {
            croak 'problem opening file to dump instid map to.';
        }
    }

    # foreach my $v ( keys %instid_map ) {
    # print "$v " . $instid_map{$v} . "\n";
    # }
    $institutions->{'InstIDMap'} = \%instid_map;
    return 1;
}

#}}}

#{{{sub print_inst_membership_count
sub print_inst_membership_count {
    my ( $institutions, $out, $inst_membership_count_map ) = @_;
    foreach my $v ( sort keys %{$inst_membership_count_map} ) {
        print $out "Number of users who are members of $v institution(s): "
          . $inst_membership_count_map->{$v}
          . "\n" || croak 'problem printing';
    }
    return 1;
}

#}}}

#{{{sub inst_membership_count
sub inst_membership_count {
    my ($institutions) = @_;
    my %inst_membership_count_map;
    foreach my $user ( keys %{ $institutions->{'InstitutionMap'} } ) {
        $inst_membership_count_map{ @{ $institutions->{'InstitutionMap'}
                  ->{$user} } } =
          defined
          $inst_membership_count_map{ @{ $institutions->{'InstitutionMap'}
                  ->{$user} } }
          ? $inst_membership_count_map{ @{ $institutions->{'InstitutionMap'}
                  ->{$user} } } + 1
          : 1;
    }

    # Output the stats to the working directory:
    if (
        open my $out,
        '>',
        ${ $institutions->{'Stats'} }->{'WorkDir'}
        . '/inst_membership_count.csv'
      )
    {
        $institutions->print_inst_membership_count( $out,
            \%inst_membership_count_map );
        close($out);
    }
    else {
        croak
          'problem opening file to write inst membership count statistics to.';
    }
    return 1;
}

#}}}

#{{{sub print_unique_for_month
sub print_unique_for_month {
    my ( $institutions, $out, $year, $month, $instid_counts ) = @_;
    foreach my $v ( sort keys %{$instid_counts} ) {
        my $instname =
          defined $institutions->{'InstIDMap'}->{$v}
          ? $institutions->{'InstIDMap'}->{$v}
          : 'unknown_name';
        print $out "$year|$month|$v|"
          . $instname . '|'
          . $instid_counts->{$v}
          . "|\n" || croak 'problem printing';
    }
    return 1;
}

#}}}

#{{{sub build_instid_counts
sub build_instid_counts {
    my ( $institutions, $year, $month, $database, $instid_counts ) = @_;
    ${$database}->inst_users_per_month( $year, $month );
    my $session_user;
    ${$database}->{'QueryHandle'}->bind_columns( undef, \$session_user );
    my %users_seen;
    while ( ${$database}->{'QueryHandle'}->fetch() ) {

        # We are only interested in unique users:
        if ( !defined $users_seen{$session_user} ) {

            # Keep track of the users we see in the users_seen hash:
            $users_seen{$session_user} = 1;
            if ( defined $institutions->{'InstitutionMap'}->{$session_user} ) {

                # User is in institution map:
                foreach (
                    @{ $institutions->{'InstitutionMap'}->{$session_user} } )
                {
                    if ( defined $instid_counts->{$_} ) {
                        $instid_counts->{$_} = $instid_counts->{$_} + 1;
                    }
                    else {
                        $instid_counts->{$_} = 1;
                    }
                }
            }
            else {

                # User unknown in institution map:
                if ( $session_user =~ /^admin-[^@]+$/x ) {

                    # User is an admin user:
                    $instid_counts->{'admin_users'} =
                      defined $instid_counts->{'admin_users'}
                      ? $instid_counts->{'admin_users'} + 1
                      : 1;
                }
                elsif ( $session_user =~ /^.*@.*$/x ) {

                    # User is a friends user
                    $instid_counts->{'friends_users'} =
                      defined $instid_counts->{'friends_users'}
                      ? $instid_counts->{'friends_users'} + 1
                      : 1;
                }
                else {

         # User has an unknown id - probably someone who has left the university
                    $instid_counts->{'unknown_id'} =
                      defined $instid_counts->{'unknown_id'}
                      ? $instid_counts->{'unknown_id'} + 1
                      : 1;
                }
            }
        }
    }

    return 1;
}

#}}}

#{{{sub unique_for_month
sub unique_for_month {
    my ( $institutions, $year, $month, $database ) = @_;

    if (  -e ${ $institutions->{'Stats'} }->{'WorkDir'}
        . '/unique_instids_'
        . $year . '_'
        . $month
        . '.csv' )
    {

# An archive of the institution stats has already been created for this year and month, so simply output that:
        if (
            open my $in,
            '<',
            ${ $institutions->{'Stats'} }->{'WorkDir'}
            . '/unique_instids_'
            . $year . '_'
            . $month . '.csv'
          )
        {
            if (
                open my $out,
                '>>',
                ${ $institutions->{'Stats'} }->{'WorkDir'}
                . '/unique_instids.csv'
              )
            {
                while (<$in>) { print $out $_ || croak 'problem printing' }
                close $in;
                close $out;
            }
            else {
                croak 'problem opening file to write statistics to.';
            }
        }
        else {
            croak 'problem reading in institution archive file: '
              . ${ $institutions->{'Stats'} }->{'WorkDir'}
              . '/unique_instids_'
              . $year . '_'
              . $month . '.csv';
        }

    }
    else {

        # No archive of statistics exists, so fetch data from database instead:
        my %instid_counts;
        $institutions->build_instid_counts( $year, $month, $database,
            \%instid_counts );

        my ( $sec, $min, $hour, $mday, $actual_month, $actual_year, $wday,
            $yday, $isdst )
          = localtime(time);
        # Normalize year and month:
        $actual_year += 1900;
        $actual_month++;
        if ( $actual_year > $year
            || ( $actual_year == $year && $actual_month > $month ) )
        {

            # Output stats to an archive file in the working directory:
            if (
                open my $out,
                '>>',
                ${ $institutions->{'Stats'} }->{'WorkDir'}
                . '/unique_instids_'
                . $year . '_'
                . $month . '.csv'
              )
            {
                $institutions->print_unique_for_month( $out, $year, $month,
                    \%instid_counts );
                close($out);
            }
            else {
                croak 'problem opening archive file to write statistics to.';
            }
        }

        # Output stats to the main statistics file in the working directory:
        if (
            open my $out,
            '>>',
            ${ $institutions->{'Stats'} }->{'WorkDir'} . '/unique_instids.csv'
          )
        {
            $institutions->print_unique_for_month( $out, $year, $month,
                \%instid_counts );
            close($out);
        }
        else {
            croak 'problem opening file to write statistics to.';
        }
    }
    return 1;
}

#}}}

1;

__END__

=head1 NAME

Sakai::Stats::Institutions

=head1 ABSTRACT

Library that allows a user id to be mapped to one or more institutions.

=head1 METHODS

=head2 new

Create, set up, and return an Institutions object.

=head2 perform_search

Given an ldap connection, search string, attributes and base, this method
performs the ldap search and returns the result as a perl data structure.

=head2 populate_user_insts

Populates the institution map with user id as the key and an array of
institutions the uid is a member of as the value.

=head2 populate_inst_names

Populates the instid map with institution id as the key and the human readable
name for the institution as the value.

=head2 ldap_connect

Connect to the LDAP host with the given configuration.

=head2 generate_user_insts

This is the top level method for setting up the uid to institutions map.

=head2 generate_names_for_ids

This is the top level method for setting up the instid to institution name map.

=head2 print_inst_membership_count

Method for printing to the provided file handle a representation of the membership count data.

=head2 inst_membership_count

Print out the number of people who are members of 1,2,3,4... etc. institutions.

=head2 print_unique_for_month

Print the number of unique users from an institution for a given month.

=head2 build_instid_counts

Fetches data from a specified database server to construct the instid counts.

=head2 unique_for_month

Print out the number of unique users from each institution for a given month.

=head1 USAGE

use Sakai::Stats::Institutions;

=head1 DESCRIPTION

Library to map users to institutions they are a member of.

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
