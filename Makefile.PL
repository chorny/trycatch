use strict;
use warnings;

use FindBin qw/$Bin/;

use inc::Module::Install 0.79;

perl_version '5.008001';
name 'TryCatch';
all_from 'lib/TryCatch.pm';

requires 'Parse::Method::Signatures' => '1.003003';
requires 'B::Hooks::EndOfScope' => 0.05;
requires 'B::Hooks::OP::Check' => 0.15;
requires 'B::Hooks::OP::PPAddr' => 0.02;
requires 'Devel::Declare' => '0.003004';
requires 'Moose';
requires 'MooseX::Types::Moose';
requires 'MooseX::Types';
requires 'Scope::Upper' => 0.06;
requires 'Variable::Magic' => 0.28;
requires 'Sub::Exporter' => 0.979;
requires 'XSLoader';

resources repository => 'http://github.com/ashb/trycatch/tree/master';

auto_provides;

configure_requires 'ExtUtils::Depends' => 0.302; #minimum version that works on Win32+gcc
configure_requires 'B::Hooks::OP::Check' => '0.18';
#minimum version that depends on ExtUtils::Depends 0.302
configure_requires 'B::Hooks::OP::PPAddr' => 0.03;
#minimum version that depends on ExtUtils::Depends 0.302
my $ok = 1;

# Does the toolchain support configure_requires
# If yes, it should be here already.
can_use('ExtUtils::Depends') or do {
  warn "***\n* Your CPAN toolchain is out of date. Please upgrade it\n***\n"; sleep 5;
  requires 'ExtUtils::Depends';
  requires 'B::Hooks::OP::Check' => 0.15;
  requires 'B::Hooks::OP::PPAddr' => 0.02;
  
};

# Currently CPAN client dont seem to get on with JSON meta, so always use our 
# version from inc/EUDeps
unshift @INC, "$Bin/inc/EUDeps";
can_use('ExtUtils::Depends') or do {
  warn "ExtUtils::Depends not installed and can't use version from inc!";
  $ok = 0;
};


unless ($ok) {
  WriteAll;
  exit 1;
}

my $pkg = ExtUtils::Depends->new('TryCatch', 'B::Hooks::OP::PPAddr', 'B::Hooks::OP::Check');
makemaker_args(
    $pkg->get_makefile_vars,
);

{ no warnings 'once';
if ($Module::Install::AUTHOR) {
  system('pod2text lib/TryCatch.pm > README');

  # Pull in the header files from B::Hooks modules we need.
  # This only works since I know they only use .h files, not XS or typemaps.

  #  Author only - use what ever modules we like!
  require Path::Class;
  require File::Copy::Recursive;

  Path::Class::dir(qw/inc EUDeps/)->rmtree;

  $File::Copy::Recursive::KeepMode = 0;
  my %deps = $pkg->get_deps;
  while (my ($mod, $conf) = each %deps ) {
    my $dest = Path::Class::dir('inc', 'EUDeps', split(/::/, $mod), 'Install', );
    my $src = Path::Class::dir($conf->{instpath});

    File::Copy::Recursive::dircopy("$src", "$dest");
  }
  File::Copy::Recursive::fcopy($INC{'ExtUtils/Depends.pm'}, 'inc/EUDeps/ExtUtils/');
}
}

WriteAll;


