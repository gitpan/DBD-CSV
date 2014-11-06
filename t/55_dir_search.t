#!/pro/bin/perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok ("DBI") }
require "t/lib.pl";

my $tstdir = DbDir ();
my @extdir = ("t", File::Spec->tmpdir ());
if (open my $fh, "<", "tests.skip") {
    grep m/\b tmpdir \b/x => <$fh> and pop @extdir;
    }
my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema         => undef,
    f_dir            => DbDir (),
    f_dir_search     => \@extdir,
    f_ext            => ".csv/r",
    f_lock           => 2,
    f_encoding       => "utf8",

    RaiseError       => 1,
    PrintError       => 1,
    FetchHashKeyName => "NAME_lc",
    }) or die "$DBI::errstr\n";

my @dsn = $dbh->data_sources;
my %dir = map {
    m{^dbi:CSV:.*\bf_dir=([^;]+)}i;
    my $folder = $1;
    # data_sources returns the string just one level to many
    $folder =~ m{\\[;\\]} and $folder =~ s{\\(.)}{$1}g;
    ($folder => 1);
    } @dsn;

# Use $test_dir
$dbh->do ("create table foo (c_foo integer, foo char (1))");
$dbh->do ("insert into foo values ($_, $_)") for 1, 2, 3;

my @test_dirs = ($tstdir, @extdir);
is ($dir{$_}, 1, "DSN for $_") for @test_dirs;

my %tbl = map { $_ => 1 } $dbh->tables (undef, undef, undef, undef);

is ($tbl{$_}, 1, "Table $_ found") for qw( tmp foo );

my %data = (
    tmp => {		# t/tmp.csv
	1 => "ape",
	2 => "monkey",
	3 => "gorilla",
	},
    foo => {		# output123/foo.csv
	1 => 1,
	2 => 2,
	3 => 3,
	},
    );
foreach my $tbl ("tmp", "foo") {
    my $sth = $dbh->prepare ("select * from $tbl");
    $sth->execute;
    while (my $row = $sth->fetch) {
	is ($row->[1], $data{$tbl}{$row->[0]}, "$tbl ($row->[0], ...)");
	}
    }
# Do not drop table foo yet

ok ($dbh->disconnect, "disconnect");

chdir DbDir ();
my @f = grep m/^foo\.csv/i => glob "*.*";
is (scalar @f, 1, "foo.csv still here");

SKIP: {
    $DBD::File::VERSION < 0.43 and skip "DBD::File-0.43 required", 1;
    is (DBI->connect ("dbi:CSV:", undef, undef, {
	f_schema   => undef,
	f_dir      => "./undefined",
	f_ext      => ".csv/r",

	RaiseError => 0,
	PrintError => 0,
	}), undef, "Should not be able to connect to non-exiting folder");
    }

# drop table foo;
@f and unlink @f;

done_testing;
