#---------------------------------------------------------
# $Id$

=head1 NAME

Bio::Matrix::PSM::IO::masta - motif fasta format parser

=head1 SYNOPSIS
MASTA is a position frequency matrix format similar to fasta. It contains one ID row just
like fasta and then the actual data, which is tab delimited:
0.1	0.62	.017	0.11
0.22	0.13	0.54	0.11

Or A,C,G and T could be horizontally positioned. Please note masta will parse only DNA at
the moment.


See Bio::Matrix::PSM::IO for detailed documentation on how to use masta parser

=head1 DESCRIPTION

Parser for meme.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this
and other Bioperl modules. Send your comments and suggestions preferably
 to one of the Bioperl mailing lists.
Your participation is much appreciated.

  bioperl-l@bioperl.org                 - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
 the bugs and their resolution.
 Bug reports can be submitted via email or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR - Stefan Kirov

Email skirov@utk.edu

=head1 APPENDIX

=cut


# Let the code begin...
package Bio::Matrix::PSM::IO::masta;
use Bio::Matrix::PSM::IO;
use Bio::Matrix::PSM::SiteMatrix;
use vars qw(@ISA @HEADER);
use strict;

@ISA=qw(Bio::Matrix::PSM::IO Bio::Root::Root);



=head2 new

 Title   : new
 Usage   : my $psmIO =  new Bio::Matrix::PSM::IO(-format=>'masta',
						 -file=>$file, -mtype=>'pwm');
 Function: Associates a file with the appropriate parser
 Throws  :
 Example :
 Args    : hash
 Returns : "Bio::Matrix::PSM::$format"->new(@args);

=cut

sub new {
    my($class, @args)=@_;
    my $self = $class->SUPER::new(@args);
    my ($file)=$self->_rearrange(['FILE'], @args);
    my ($query,$tr1)=split(/\./,$file,2);
    $self->{file} = $file;
    $self->{_end}  = 0;
    $self->{mtype}=uc($self->_rearrange(['MTYPE'], @args) || "PFM");
    $self->_initialize_io(@args) || warn "Did you intend to use STDIN?"; #Read only for now
    return $self;
}

=head2 write_psm

 Title   : write_psm
 Usage   : 
 Function: 
 Throws  :
 Example :
 Args    : 
 Returns : 

=cut

sub write_psm {
    my ($self,$matrix)=@_;
    my $idline=">". $matrix->id . "\n";
    $self->_print($idline);
    while (my %h=$matrix->next_pos) {
	my $row=$self->{mtype} eq 'PWM' ? join("\t",$h{lA},$h{lC},$h{lG},$h{lT},"\n"):join("\t",$h{pA},$h{pC},$h{pG},$h{pT},"\n");
	$self->_print ($row);
    }
}

=head2 next_matrix

 Title   : next_matrix
 Usage   :
 Function:
 Throws  :
 Example :
 Args    :
 Returns : Bio::Matrix::PSM::SiteMatrix

=cut

sub next_matrix {
    my $self=shift;
    return undef if ($self->{_end});
    my $line=$self->_readline;
    $self->throw("No ID line- wrong format\n") unless ($line=~/^>/);
    my ($id,$desc)=split(/[\t\s]+/,$line,2);
    $id=~s/>//;
    my ($mtype,$format,@mdata);
    while ($line=$self->_readline) {
      chomp $line;
      next if ($line eq '');
      if ($line=~/^>/) {
          $self->_pushback($line);
          last;
      }
      $line=~s/[a-zA-Z]//g;  #Well we may wanna do a hash and auto check for letter order if there is a really boring talk...
      $line=~s/^[\s\t]+//;
      $line=~s/[\s\t]+/\t/g;
      my @data=split(/\t/,$line);
      if ($#data==3) {
         $self->throw("Type 1 and type 2 formats cannot be mixed or a parsing error occured\n") if (($self->{_mtype} !=1) &&($mtype)) ;
         $self->{_mtype}=1;
         $mtype=1;
      }
      else   {
         $self->throw("Type 1 and type 2 formats cannot be mixed or a parsing error occured\n") if (($self->{_mtype} !=2) &&($mtype)) ;
         $self->{_mtype}=2;
         $mtype=1;
      }
      push @mdata,\@data;
    }
    $self->{_end}=1 if  ($line!~/^>/);
    return _make_matrix(\@mdata,$self->{_mtype},$id,$desc);
}

sub _make_matrix {
my ($mdata,$type,$id,$desc)=@_;
$mdata=_rearrange_matrix($mdata) if ($type==1);
my ($a,$c,$g,$t)=@{$mdata};
#Auto recognition for what type is this entry (PFM, PWM or simple count)
#A bit dangerous, I hate too much auto stuff, but I want to be able to mix different
#types in a single file
my $mformat='count';
my $k=$a->[0]+$c->[0]+$g->[0]+$t->[0];
my $l= ($a->[0]+$c->[0]+$g->[0]+$t->[0]) - 
		(abs($a->[0])+abs($c->[0])+abs($g->[0])+abs($t->[0]));
$mformat='freq' if (($k==1) && ($l==0));
$mformat='pwm' if ($l!=0);
my (@fa,@fc,@fg,@ft,%mparam);
if ($mformat eq 'pwm') {
  foreach my $i (0..$#{$a}) {
    my $ca=$a->[$i] if ($a->[$i]>0);
    my $cc=$c->[$i] if ($c->[$i]>0);
    my $cg=$g->[$i] if ($g->[$i]>0);
    my $ct=$t->[$i] if ($t->[$i]>0);
    my $all=$ca+$cc+$cg+$ct;
    push @fa,($ca/$all)*100;
    push @fc,($cc/$all)*100;
    push @fg,($cg/$all)*100;
    push @ft,($ct/$all)*100;
  }
}
$desc.=", source is $mformat";
if ($mformat eq 'pwm') {
  $desc=~s/^pwm//;
  %mparam=(-pA=>\@fa,-pC=>\@fc,-pG=>\@fg,-pT=>\@ft,-id=>$id,-desc=>$desc,
           -lA=>$a,-lC=>$c,-lG=>$g,-lT=>$t);
}
else {
  %mparam=(-pA=>$a,-pC=>$c,-pG=>$g,-pT=>$t,-id=>$id,-desc=>$desc);
}
return new Bio::Matrix::PSM::SiteMatrix(%mparam);
}

sub _rearrange_matrix {
my $mdata=shift;
my (@a,@c,@g,@t);
foreach my $entry (@{$mdata}) {
    my ($a,$c,$g,$t)=@$entry;
    push @a,$a;
    push @t,$t;
    push @g,$g;
    push @t,$t;
}
return \@a,\@c,\@g,\@t;
}

