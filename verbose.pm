
# pass VERBOSE => 0, 1..N
# 0 is off  1-N are levels to display by 
# subsequent print() calls
#  pass LABELS=> 0 or 1 - off or on
#  pass TIMESTAMP=> 0 or 1 - off or on
# pass handle for output 
# can be filehandle, stderr, stdout, etc

=head1 ABSTRACT

 A simpple module used to provide optional debugging 
 and informational messages

=head1 SYNOPSIS

use verbose;

  my $d = verbose->new(
  {
    VERBOSITY=>3, 
    LABELS=>1, 
    TIMESTAMP=>1, 
    HANDLE=>*STDERR
    } 
  );

my %h=(a=>1, b=>2, c=>3);

print "doing some work with \%h\n";
$d->print(2,'reference to %h', \%h);

=head1 DESCRIPTION

This module is used to enable varying levels of verbose
output from your Perl scripts. 

The levels are 1..N

=head1 AUTHOR

	Jared Still jkstill@gmail.com

=cut


package verbose;

use strict;
use warnings;

require Exporter;
our @ISA= qw(Exporter);
#our @EXPORT_OK = ( 'showself','print');
our $VERSION = '0.02';

use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);

=head2 new

 Create a new verbose object

 my $verbosity=2;
 my $useTimestamp=1;

 my $d = verbose->new(
    {
       VERBOSITY=>$verbosity,
       LABELS=>1,
       TIMESTAMP=>$useTimestamp,
       HANDLE=>*STDERR
    }
 );


=cut


sub new {

	use Data::Dumper;
	use Carp;

	my $pkg = shift;
	my $class = ref($pkg) || $pkg;
	#print "Class: $class\n";
	my ($args) = @_;
	#print 'args: ' , Dumper($args);
		
	# handle could be stdout,stderr, filehandle, etc
	my $self = { 
		VERBOSITY=>$args->{VERBOSITY}, 
		LABELS=>$args->{LABELS}, 
		HANDLE=>$args->{HANDLE},
		TIMESTAMP=>$args->{TIMESTAMP},
		CLASS=>$class 
	};

	#$self->{LABELS}=0 unless defined $self->{LABELS};
	$self->{HANDLE}=*STDOUT unless defined $self->{HANDLE};

	#print Dumper($self);
	{ 
		no warnings;
		if ( (not defined $self->{VERBOSITY}) || (not defined $self->{LABELS}) ) { 
			warn "invalid call to $self->{CLASS}\n";
			warn "call with \nmy \$a = $self->{CLASS}->new(\n";
			warn "   {\n";
			warn "      VERBOSITY=> (level - 0 or 1-N),\n";
			warn "      LABELS=> (0 or 1)\n"; 
			warn "   }\n";
			croak;
		}
	}
	my $retval = bless $self, $class;
	return $retval;
}

=head2 showself

  Simply dump the class attributes

 $d->showself;

 $VAR1 = bless( {
                 'CLASS' => 'verbose',
                 'HANDLE' => *::STDERR,
                 'VERBOSITY' => 2,
                 'TIMESTAMP' => 0,
                 'LABELS' => 1
               }, 'verbose' );

=cut 

sub showself {
	use Data::Dumper;
	my $self = shift;
	print Dumper($self);
}

=head2 getlvl

 Return the level of verbosity set when new was called:
 This is useful to prevent calling verbose->print when 
 the verbosity level is 0. As the print method returns
 quite early if the verbosity level is too low, the
 savings from doing this may be negligible.

 $d->getlvl && $d->print(2,'reference to %h', \%h);

=cut

sub getlvl {
	my $self = shift;
	$self->{VERBOSITY};
}

=head2 print
 
 Call print with verbosity level, label and data

 $d->print(2,"This is a label",[0,1,2])
 $d->print(4,'anonymous array ref', [7,8,9]);
 
=cut


sub print {
	use Carp;
	my $self = shift;
	my ($verboseLvl,$label, $data) = @_;

	return unless ($verboseLvl <= $self->{VERBOSITY} );

	# handle could be stdout,stderr, filehandle, etc
	my $handle = $self->{HANDLE};
	#print $handle Dumper($self);

	#print "VERBOSITY LVL: $self->{VERBOSITY} \n";
	my $padding='  ' x $verboseLvl;
	#print "PADDING: $padding|\n";

	my $isRef = ref($data) ? 1 : 0;

	unless ($isRef) {carp "Must pass a reference to $self->{class}->print\n" }

	my $refType = ref($data);
	#print "reftype: $refType\n";

	my $wallClockTime='';
	my ($dummy,$microSeconds)=(0,0);
	if ( $self->{TIMESTAMP} ) {
		($dummy,$microSeconds)=gettimeofday();
		$wallClockTime = strftime("%Y-%m-%d %H:%M:%S",localtime) . '.' . sprintf("%06d",$microSeconds);
	}

	print $handle "$wallClockTime$padding======= $label - level $verboseLvl =========\n" if $self->{LABELS} ;
	
	my $isThereData=0;

	if ('ARRAY' eq $refType) {
		if (@{$data}) {
			print $handle $padding, join("\n" . $padding, @{$data}), "\n";
			$isThereData=1;
		}
	} elsif ('HASH' eq $refType) {
		#print "HASH: ", Dumper(\$data);
		if (%{$data}) {
			foreach my $key ( sort keys %{$data} ) {
				print $handle "${padding}$key: $data->{$key}\n";
			}
			$isThereData=1;
		}
	} else { croak "Must pass reference to a simple HASH or ARRAY to  $self->{CLASS}->print\n" }

	# no point in printing a separator if an empty hash or array was passed
	# this is how to do label only
	print $handle "$padding============================================\n" if $self->{LABELS} and $isThereData;

}

1;

__END__

=head1 Verbose demo

 use lib './';

 use verbose;

 my $d = verbose->new(
   {
     VERBOSITY=>3, 
     LABELS=>1, 
     TIMESTAMP=>1, 
     HANDLE=>*STDERR
   } 
 );

 #$d->showself;

 my @a=(1,2,3);
 my %h=(a=>1, b=>2, c=>3);
 my $x=1;

 #$d->print(@a);
 #$d->print(%h);

 print "doing some work with \@a\n";
 $d->print(1,'reference to @a', \@a);

 print "doing some work with \%h\n";
 $d->print(2,'reference to %h', \%h);

 print "doing some work with with an anonymous hash\n";
 $d->print(3,'anonymous hash ref', {x=>24, y=>25, z=>26});

 print "doing some work with with an anonymous array\n";
 $d->print(4,'anonymous array ref', [7,8,9]);


=cut
