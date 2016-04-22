#!/usr/bin/perl

# template for DBI programs

use warnings;
use FileHandle;
use strict;
use Data::Dumper;
use Getopt::Long;

use lib './';
use verbose;

my $debug=0;
my %optctl = ();

Getopt::Long::GetOptions(
	\%optctl, 
	"oracle_home=s",
	"linux_patch_list=s",
	"verbosity=i",
	"long_report!",
	,"h","help");


my ($ohome,$patchList, $verbosity);
my $longReport=0;
if ( defined($optctl{long_report}) ) {
	$longReport=$optctl{long_report};
}

if ( defined($optctl{h}) or defined($optctl{help}) ) {
	usage(0);
}

if ( ! defined($optctl{verbosity}) ) {
	$verbosity = 1;
} else {
	$verbosity = $optctl{verbosity};
}

my $d = verbose->new(
	{
		VERBOSITY=>$verbosity,
		LABELS=>1,
		TIMESTAMP=>1,
		HANDLE=>*STDOUT
	}
);

if ( ! defined($optctl{oracle_home}) ) {
	usage(1);
}
$ohome=$optctl{oracle_home};

if ( ! defined($optctl{linux_patch_list}) ) {
	usage(2);
}
$patchList=$optctl{linux_patch_list};

-r $patchList && -f $patchList|| die "cannot open $patchList\n";

=head1 patch list processing

file name is <name>-<version>-<release>-<architecture>

the list of patches should not include the .rpm suffix on the filename
if it does, remove it

Unfortunately the name may have 1+ dashes in it, so we need to
work from the right end of the name to break it down.

eg.
  popt-1.10.2.3-22.el5_6.2.i386
  kernel-headers-2.6.18-238.27.1.el5.x86_64
  kernel-devel-2.6.18-238.27.1.el5.x86_64
  popt-1.10.2.3-22.el5_6.2.x86_64
  kernel-2.6.18-238.27.1.el5.x86_64


=cut

-d $ohome && -x $ohome || die "$ohome does not exist or has wrong permissions\n";

################################
### build %rpmPatches
################################

# break down patch rpm list into package, version and architecture
open PATCHLIST, "<$patchList";

my @rpmPatchList = <PATCHLIST>;
close PATCHLIST;
chomp @rpmPatchList;

my %rpmPatches = ();

my $rpms = new rpmProcess( {PATCH_LIST => \@rpmPatchList, RPM_PATCHES => \%rpmPatches});

$rpms->parse;

my @dd=Dumper(\%rpmPatches);
$d->print(1,'%rpmPatches', \@dd);


################################
### end of building %rpmPatches
################################

################################
### generate lib dependencies
################################

=head1 Get Oracle Dependencies

	using system 'find' rather than File::Find as 
	it is necessary to also determine the type of file
	there is a File::Type module, but it is not part of 
	std perl and may not be installed on client server

=cut

# track dependencies here
my %olibDepend=();
my %opkgDepend=();
my %olibDependPkg=();

my $odep = new getoDepend( 
	{
		OLIB_DEPS => \%olibDepend,
		OPKG_DEPS => \%opkgDepend,
		OLIB_DEP_PKG => \%olibDependPkg,
		CMDS => { 
			find	=> '/usr/bin/find',
			file	=> '/usr/bin/file',
			ldd	=> '/usr/bin/ldd',
			rpm	=> '/bin/rpm',
			grep	=> '/bin/grep',
			xargs	=> '/usr/bin/xargs',
			cut	=> '/bin/cut',
		},
	}
);
		

$odep->getDeps;

@dd=Dumper(\%olibDepend);
print '#### Dumper %olibDepend - ' , Dumper(\@dd) if $debug;
@dd=Dumper(\%opkgDepend);
print '#### Dumper %opkgDepend - ' , Dumper(\@dd) if $debug;
@dd=Dumper(\%olibDependPkg);
print '#### Dumper %olibDependPkg - ' , Dumper(\@dd) if $debug;

################################
### end of %olibDepend
################################

###############################################
## report out
###############################################

=head1 Compare Oracle dependency list to patch packages

Walk through the list of oracle dependencies in %opkgDepend
and compare to the packages to be applied in %rpmPatches

=cut


my $printedBanner=0;
foreach my $rpm ( sort keys %rpmPatches ) {
	if (exists $opkgDepend{$rpm}) {

		$printedBanner || print "\n\n#### Possible Conflicts Found #####\n";
		$printedBanner || $printedBanner++;

		print '-' x 20, "\n--- $rpmPatches{$rpm}->{rpm}\n";
		printf "old: %s20 %s20\n",$opkgDepend{$rpm}->{version},$opkgDepend{$rpm}->{release};
		printf "new: %s20 %s20\n",$rpmPatches{$rpm}->{version},$rpmPatches{$rpm}->{release};

		# report on oracle dependents if -long_report
		# show lib files from packages
		#   show oracle dependents on lib file
		my $pad=chr(32) x 3;
		if ($longReport) {
			print $pad . "=== RPM lib file and oracle dependent files ===\n";
			foreach my $libFile ( sort @{$olibDependPkg{$rpm}{files}} ) {
				print $pad . "$libFile\n";
				foreach my $dependent ( sort @{$olibDepend{$libFile}{dependents}} ) {
					print $pad x 2 . "$dependent\n";
				}
			}	
		}
	}
}

$printedBanner || print "#### No Conflicts Found #####\n";

print "\n";

# end of main program

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq/

usage: $basename

  -oracle_home       directory that is oracle home
  -linux_patch_list  file containing linux patch names
  -verbosity         0 or 1 - default is 0
  -long_report       show dependent files as well as possible conflicts
                     default is -no-long_report

  example:

  $basename -oracle_home \$ORACLE_HOME -linux_patch_list linux_patches.txt

/;
   exit $exitVal;
};


sub parseRPM {
	my $rpm = shift;
	
	# includes x86
	if ($rpm =~ /^(.+)-([^-]+)-([^-]+)\.(\w+)$/ ) {
		return [$1,$2,$3,$4];
	}

	# no architecture included
   if ($rpm =~ /^(.+)-([^-]+)-([^-]+)$/ ) {
		return [$1,$2,$3];
	}

	# this line will print when a file does not belong
	# to any installed package - for debugging
	#print "### Parse Failed for $rpm###\n";

	[0];
}


package rpmProcess;

use strict;
use Carp;
use Data::Dumper;

sub new {
	my $pkg = shift;
	my $class = ref($pkg) || $pkg;

	my %args = %{$_[0]};
	#print Dumper(\%args);

	my $patchList = $args{PATCH_LIST};
	my $rpmPatches = $args{RPM_PATCHES};


	croak "Attribute PATCH_LIST is required in $class::new\n" unless $args{PATCH_LIST};
	croak "Attribute RPM_PATCHES is required in $class::new\n" unless $args{RPM_PATCHES};

   return bless my $self = { patchList => $patchList, rpmPatches => $rpmPatches } => ( ref $class || $class );

}


sub parse {

	my $self = shift;

	#print '#### $self->{patchList} ####', "\n", Dumper($self->{patchList});
	#print '#### $self->{rpmPatches} ####', "\n", Dumper($self->{rpmPatches});

	foreach my $rpm ( @{$self->{patchList}} ) {

		#print "#### RPM: $rpm\n";

		my $components = main::parseRPM($rpm);
		my ($package,$version,$release,$arch) = @{$components};

		#print qq{##########################
	#rpm      : $rpm
	#name     : $package
	#version  : $version
	#release  : $release
	#arch     : $arch
	#};

		$self->{rpmPatches}->{$package} = {
			rpm		=> $rpm,
			version	=> $version,
			release	=> $release,
			arch		=> $arch
		}

	}

	#print '#### $self->{rpmPatches} ####', "\n", Dumper($self->{rpmPatches});
	
}


package getoDepend;

use strict;
use Carp;
use Data::Dumper;

sub new {
	my $pkg = shift;
	my $class = ref($pkg) || $pkg;

	my %args = %{$_[0]};
	#print Dumper(\%args);
	#exit;

	croak "Attribute OLIB_DEPS is required in $class::new\n" unless $args{OLIB_DEPS};
	croak "Attribute OPKG_DEPS is required in $class::new\n" unless $args{OPKG_DEPS};
	croak "Attribute OLIB_DEP_PKG is required in $class::new\n" unless $args{OLIB_DEP_PKG};
	croak "Attribute CMDS is required in $class::new\n" unless $args{CMDS};

	my $olibDeps = $args{OLIB_DEPS};
	my $cmds = $args{CMDS};
	my $opkgDeps = $args{OPKG_DEPS};
	my $olibDepPkg = $args{OLIB_DEP_PKG};

   return bless my $self = { 
		olibDeps => $olibDeps, 
		opkgDeps => $opkgDeps, 
		olibDepPkg => $olibDepPkg, 
		cmds => $cmds ,
	} => ( ref $class || $class );

}


sub getDeps {

	my $self = shift;

	#print '#### $self->{olibDeps} ####', "\n", Dumper($self->{olibDeps});
	#print '#### $self->{cmds} ####', "\n", Dumper($self->{cmds});

	my %cmds = %{$self->{cmds}};

	#print '#### %cmds ####', "\n", Dumper(\%cmds);

	foreach my $cmd ( keys %cmds ) {
		-x $cmds{$cmd} || die "$cmds{$cmd} not found\n";
	}

	# list of executable files
	my @oexe=qx($cmds{find} $ohome -perm /u+x -type f | $cmds{xargs} $cmds{file} | $cmds{grep} ' ELF ' | $cmds{cut} -d: -f1 );
	chomp @oexe;

	foreach my $exe (@oexe) {
		#print "#################################################################\n";
		#print "working on $exe\n";
		my @lddFiles=qx($cmds{ldd} $exe 2>/dev/null);
		unless (@lddFiles) {
			warn "##### ldd error ############\n";
			warn "error encountered with $cmds{ldd} $exe\n";
			warn "run the command manually to see the error\n";
			next;
		}
		chomp @lddFiles;
		# if the line starts with / it is a filename (address)
		# otherwise libname => filename (address)
		foreach my $line (@lddFiles) {
			$line =~ s/^\s+//;
			#print " ########## LINE:$line\n";
	
			# some dependencies may not be found for a number of reasons
			# could be java stuff that is not setup, and no CLASSPATH is set
			# just warn about 'not found' output from ldd
			if ( $line =~ m/not found/ ) {
				warn " ###########################\n";
				warn " working on $exe dependencies\n";
				warn " $line\n";
				next;
			}

			my ($file,$dummy1,$dummy2);
			if ( $line =~ m#^/# ) {
				($file) = split(/\s+/,$line);
			} else {
				($dummy1,$dummy2,$file) = split(/\s+/,$line);
			}

			#print "      ###### FILE: $file\n";
			push @{$self->{olibDeps}->{$file}{dependents}}, $exe if $file;
		}
	}

	# all library dependencies now in %olibDepend
	# now get the names of the packages that dependent files are in

	my %opkgDepend=();
	my %olibDependPkg=();

	# this will also update the %olibDepend hash with the package name
	# this will be used for extended reporting when we want to see the
	# name of the dependent oracle files as well as the package

	my @dd;
	#foreach my $libFile ( keys %olibDepend ) {
	foreach my $libFile ( keys %{$self->{olibDeps}} ) {

		# skip if file not found - attempting to run ldd on a non-dynamic file
		# will emit unusable output
		-f $libFile || next;

		my $filePackage = qx($cmds{rpm} -qf $libFile );
		chomp $filePackage;
		my $components = main::parseRPM($filePackage);
		# parseRPM returns a 0 if the string passed is not an RPM name
		next if $components->[0] =~ /^0/;
		#print '#### $components: ', Dumper($components);
		#@dd=@{$components};
		#$d->print(1,"#### libfile: $libFile ",  '- $components', \@dd);
		my ($package,$version,$release) = @{$components};
		#$opkgDepend{$package} = {
		$self->{opkgDeps}->{$package} = {
			rpm		=> $filePackage,
			version	=> $version,
			release	=> $release
		};

		push @{$self->{olibDepPkg}->{$package}{files}}, $libFile;
	}
	
}

1;


