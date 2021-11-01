#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PGObject::Simple::Role',
    AUTHOR              => q{Chris Travers, <chris.travers@gmail.com>},
    VERSION_FROM        => 'lib/PGObject/Simple/Role.pm',
    ABSTRACT_FROM       => 'lib/PGObject/Simple/Role.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'bsd')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Carp::Clan' => 0,
        'Log::Any' => 0,
        'Moo::Role' => 0,
        'PGObject::Simple' => 3,
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'PGObject-Simple-Role-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
         resources => {
             repository => {
                 type => 'git',
                 url  => 'https://github.com/ledgersmb/PGObject-Simple-Role.git',
                 web  => 'https://github.com/ledgersmb/PGObject-Simple-Role',
             },
         },
    },
);
