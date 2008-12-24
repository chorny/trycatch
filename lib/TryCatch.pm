package TryCatch;

use strict;
use warnings;
use Sub::Exporter -setup => {
  exports => [qw/try/],
  groups => { default => [qw/try/] },
  installer => sub {
    my ($args, $to_export) = @_;
    my $pack = $args->{into};
    foreach my $name (@$to_export) {
      if (my $parser = __PACKAGE__->can("_parse_${name}")) {
        Devel::Declare->setup_for(
          $pack,
          { $name => { const => sub { $parser->($pack, @_) } } },
        );
      }
    }
    Sub::Exporter::default_installer(@_);

  }
};

# Used to detect when there is an explicity return from an eval block
our $SPECIAL_VALUE = \"no return";

use Devel::Declare ();
use B::Hooks::EndOfScope;
use B::Hooks::Parser;
use Devel::Declare::Context::Simple;
use SlimSignature;
use Moose::Util::TypeConstraints;

sub try {}

# This might be what catch should be
sub catch{
  my ($cond, $err, $tc) = @_;

  local $@ = $@;
  local *_ = \$err;

  if (defined $tc) {
    my $type = Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($tc);
    unless ($type) {
      warn "Couldn't convert '$tc' to a type constraint";
      return
    }

    return unless $type->check($err);
  }
  return $err if $cond->($err);
}

# Replace try with an actual eval call;
sub _parse_try {
  my $pack = shift;

  my $ctx = Devel::Declare::Context::Simple->new->init(@_);

  if (my $len = Devel::Declare::toke_scan_ident( $ctx->offset )) {
    $ctx->inc_offset($len);
    $ctx->skipspace;
    my $ret = $ctx->inject_if_block(
      q# BEGIN { TryCatch::try_postlude() } { BEGIN {TryCatch::try_inner_postlude() } #,
      '; my $__t_c_ret = eval');
  }
  
}

sub _parse_catch {
  my $pack = shift;
  my $ctx = Devel::Declare::Context::Simple->new->init(@_);
  my $str = $ctx->get_linestr;
  my $proto = $ctx->strip_proto || "";
  warn "proto = $proto\n";
}

sub try_inner_postlude {
  on_scope_end {
    my $offset = Devel::Declare::get_linestr_offset();
    $offset += Devel::Declare::toke_skipspace($offset);
    my $linestr = Devel::Declare::get_linestr();
    substr($linestr, $offset, 0) = q# return $TryCatch::SPECIAL_VALUE; }#;
    Devel::Declare::set_linestr($linestr);
  }
}

sub try_postlude {
  on_scope_end { try_postlude_block() }
}
sub try_postlude_block {
  my $offset = Devel::Declare::get_linestr_offset();
  $offset += Devel::Declare::toke_skipspace($offset);
  my $linestr = Devel::Declare::get_linestr();

  my $toke = '';
  my $len = 0;
  if ($len = Devel::Declare::toke_scan_word($offset, 1 )) {
    $toke = substr( $linestr, $offset, $len );
  }

  $offset = Devel::Declare::get_linestr_offset();

  my $ctx = Devel::Declare::Context::Simple->new->init($toke, $offset);

  if ($toke eq 'catch') {

    substr( $linestr, $offset, $len ) = ';';
    $ctx->set_linestr($linestr);
    $ctx->inc_offset(1);
    $ctx->skipspace;
    process_catch($ctx, 1);

  } elsif ($toke eq 'finally') {
  } else {
    my $str = '; return $__t_c_ret if !ref($__t_c_ret) || $__t_c_ret != $TryCatch::SPECIAL_VALUE;'; 
    substr( $linestr, $offset, 0 ) = $str;

    $ctx->set_linestr($linestr);
  }
}

sub process_catch {
  my ($ctx, $first) = @_;
  
  my $linestr = $ctx->get_linestr;

  if (substr($linestr, $ctx->offset, 1) eq '(') {
    my ($param, $left) = SlimSignature->param(
      input => $linestr,
      offset => $ctx->offset+1 );

    substr($linestr, $ctx->offset, length($linestr) - ($ctx->offset + length($left)), '');
    $ctx->set_linestr($linestr);
    $ctx->skipspace;

    if (substr($linestr, $ctx->offset, 1) ne ')') {
      die "')' expected after catch condition: $linestr\n";
    }
    substr($linestr, $ctx->offset, 1, '');
    $ctx->set_linestr($linestr);

    my $code;
    $code = 'else ' unless $first;

    $code .= 'if( my '
           . ($param->{var} || '$e')
           . ' = TryCatch::catch(';
    if ($param->{where}) {
      $code .= $param->{where}[0];
    } else {
      $code .= 'sub { 1 }'
    }
    $code .= ', $@';
    if ($param->{tc}) {
      $code .= ', \'' . $param->{tc} . '\''
    }

    $code .= ')) ';

    substr($linestr, $ctx->offset, 1) = $code;

    $ctx->set_linestr($linestr);
  } else {
    my $str;
    $str = 'else ' unless $first;
    $str .= 'if (my $e = $@) { '; 

    #TODO: Check a { is next thing
    substr( $linestr, $ctx->offset, 1 ) = $str;

    $ctx->set_linestr($linestr);
  }
}
1;
