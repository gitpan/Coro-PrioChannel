package Coro::PrioChannel;
{
  $Coro::PrioChannel::VERSION = '0.002';
}
use strict;
use warnings;

# ABSTRACT: Priority message queues for Coro


use Coro qw(:prio);
use Coro::Semaphore ();

use List::Util qw(first sum);

sub SGET() { 0 }
sub SPUT() { 1 }
sub DATA() { 2 }


sub new {
    # we cheat, just like Coro::Channel.
   bless [
      (Coro::Semaphore::_alloc 0), # counts data
      (Coro::Semaphore::_alloc +($_[1] || 2_000_000_000) - 1), # counts remaining space
      [], # initially empty
   ]
}


sub put {
   push @{$_[0][DATA + ($_[2]||PRIO_NORMAL()) - PRIO_MIN()]}, $_[1];
   Coro::Semaphore::up   $_[0][SGET];
   Coro::Semaphore::down $_[0][SPUT];
}


sub get {
   Coro::Semaphore::down $_[0][SGET];
   Coro::Semaphore::up   $_[0][SPUT];

   my $a = first { $_ && scalar @$_ } reverse @{$_[0]}[DATA()..DATA() + PRIO_MAX()-PRIO_MIN() + 1];

   ref $a ? shift @$a : undef;
}


sub shutdown {
   Coro::Semaphore::adjust $_[0][SGET], 1_000_000_000;
}


sub size {
    sum map { $_ ? scalar @$_ : 0 } @{$_[0]}[DATA..DATA + PRIO_MAX()-PRIO_MIN() + 1];
}


1;

__END__
=pod

=head1 NAME

Coro::PrioChannel - Priority message queues for Coro

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use Coro::PrioChannel;
    
    my $q = Coro::PrioChannel->new($maxsize);
    $q->put("xxx"[, $prio]);
    
    print $q->get;

=head1 DESCRIPTION

A Coro::PrioChannel is exactly like L<Coro::Channel>, but with priorities.
The priorities are the same as for L<Coro> itself.

Unlike Coro::Channel, you do have to load this module directly.

=over 4

=item new

Create a new channel with the given maximum size.  Giving a size of one
defeats the purpose of a priority queue.

=item put

Put the given scalar into the queue.  Optionally provide a priority between
L<Coro>::PRIO_MIN and L<Coro>::PRIO_MAX.

=item get

Return the next element from the queue at the highest priority, waiting if
necessary.

=item shutdown

Same as Coro::Channel.

=item size

Same as Coro::Channel.

=back

=head1 AUTHOR

Darin McBride <dmcbride@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Darin McBride.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

