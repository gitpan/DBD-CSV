#!/usr/bin/perl

use strict;
use Test::More tests => 15;

# This is a test for correct handling of BLOBS and $dbh->quote ()
$^W = 1;

BEGIN { use_ok ("DBI") }
do "t/lib.pl";

my $size = 128;
my @tbl_def = (
    [ "id",   "INTEGER", 4,     0 ],
    [ "name", "BLOB",    $size, 0 ],
    );

ok (my $dbh = Connect (),			"connect");

ok (my $tbl = FindNewTable ($dbh),		"find new test table");

like (my $def = TableDefinition ($tbl, @tbl_def),
	qr{^create table $tbl}i,		"table definition");
ok ($dbh->do ($def),				"create table");

ok (my $blob = (join "", map { chr $_ } 0 .. 255) x $size, "create blob");
ok (my $qblob = $dbh->quote ($blob),		"quote blob");

ok ($dbh->do ("insert into $tbl values (1, ?)", undef, $blob), "insert");

ok (my $sth = $dbh->prepare ("select * from $tbl where id = 1"), "prepare");
ok ($sth->execute,				"execute");

ok (my $row = $sth->fetch,			"fetch");
is_deeply ($row, [ 1, $blob ],			"content");

ok ($sth->finish,				"finish");
undef $sth;

ok ($dbh->do ("drop table $tbl"),		"drop table");
ok ($dbh->disconnect,				"disconnect");
