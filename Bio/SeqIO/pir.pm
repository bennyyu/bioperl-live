# $Id$
#
# BioPerl module for Bio::SeqIO::PIR
#
# Cared for by Aaron Mackey <amackey@virginia.edu>
#
# Copyright Aaron Mackey
#
# You may distribute this module under the same terms as perl itself
#
# _history
# October 18, 1999  Largely rewritten by Lincoln Stein

# POD documentation - main docs before the code

=head1 NAME

Bio::SeqIO::pir - PIR sequence input/output stream

=head1 SYNOPSIS

Do not use this module directly.  Use it via the Bio::SeqIO class.

=head1 DESCRIPTION

This object can transform Bio::Seq objects to and from pir flat
file databases.

Note: This does not completely preserve the PIR format - quality
information about sequence is currently discarded since bioperl
does not have a mechanism for handling these encodings in sequence
data.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://www.bioperl.org/MailList.shtml - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.
Bug reports can be submitted via the web:

  http://bugzilla.bioperl.org/

=head1 AUTHORS

Aaron Mackey E<lt>amackey@virginia.eduE<gt>
Lincoln Stein E<lt>lstein@cshl.orgE<gt>
Jason Stajich E<lt>jason@bioperl.orgE<gt>

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::SeqIO::pir;
use vars qw(@ISA);
use strict;

use Bio::SeqIO;
use Bio::Seq::SeqFactory;

@ISA = qw(Bio::SeqIO);

sub _initialize {
  my($self,@args) = @_;
  $self->SUPER::_initialize(@args);
  if( ! defined $self->sequence_factory ) {
      $self->sequence_factory(new Bio::Seq::SeqFactory
			      (-verbose => $self->verbose(),
			       -type => 'Bio::Seq'));
  }
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq()
 Function: returns the next sequence in the stream
 Returns : Bio::Seq object
 Args    : NONE

=cut

sub next_seq {
    my ($self) = @_;
    local $/ = "\n>";
    return unless my $line = $self->_readline;
    if( $line eq '>' ) {	# handle the very first one having no comment
	return unless $line = $self->_readline;
    }
    my ($top, $desc,$seq) = ( $line =~ /^(.+?)\n(.+?)\n([^>]*)/s )  or
	$self->throw("Cannot parse entry PIR entry [$line]");


    my ( $type,$id ) = ( $top =~ /^>?([PF])1;(\S+)\s*$/ ) or
	$self->throw("PIR stream read attempted without leading '>P1;' [ $line ]");

    # P - indicates complete protein
    # F - indicates protein fragment
    # not sure how to stuff these into a Bio object
    # suitable for writing out.
    $seq =~ s/\*//g;
    $seq =~ s/[\(\)\.\/\=\,]//g;
    $seq =~ s/\s+//g;		# get rid of whitespace

    my ($alphabet) = ('protein');
    # TODO - not processing SFS data
    return $self->sequence_factory->create
	(-seq        => $seq,
	 -primary_id => $id,
	 -id         => $id,
	 -desc       => $desc,
	 -alphabet   => $alphabet
	 );
}

=head2 write_seq

 Title   : write_seq
 Usage   : $stream->write_seq(@seq)
 Function: writes the $seq object into the stream
 Returns : 1 for success and 0 for error
 Args    : Array of Bio::PrimarySeqI objects


=cut

sub write_seq {
    my ($self, @seq) = @_;
    for my $seq (@seq) {
	$self->throw("Did not provide a valid Bio::PrimarySeqI object")
	    unless defined $seq && ref($seq) && $seq->isa('Bio::PrimarySeqI');

        $self->warn("No whitespace allowed in PIR ID [". $seq->display_id. "]")
            if $seq->display_id =~ /\s/;

	my $str = $seq->seq();
	return unless $self->_print(">P1;".$seq->id(),
				    "\n", $seq->desc(), "\n",
				    $str, "*\n");
    }

    $self->flush if $self->_flush_on_write && defined $self->_fh;
    return 1;
}

1;
