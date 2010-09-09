#!/usr/bin/perl
use Switch;
use strict;

# Hash to hold the cpu info
our(%cpus) = ();
our($cpu) = 0;

# Number of cpus
our($cpu_count) = 0;

# Total number of cores
our($total_cores) = 0;
our($total_threads) = 1;

# default thread multiplier
our($thread_mult) = 2;

# Assumes that cpu entries end with "power management"
sub count_cores {
  my($ret) = 0;
  my($num_cores) = 1;
  my($line) = '';
  while ($line = <CPUINFO>) {
    # Is this line the power management line?  If so we are done
    if ($line =~ /^power management/) {
      $ret = 1;
      last;
    }
    # Is this the cpu cores line?
    if ($line =~ /^cpu cores/) {
      ($num_cores) = ($line =~ /^cpu cores.*: (\d)/);
    }
  }

  $cpus{$cpu_count} = $num_cores;

  $ret;
}

sub get_next_cpu {
  my($ret) = 0;
  my($line) = '';
  while ($line = <CPUINFO>) {
    if ($line =~ /^processor/) {
      $ret = 1;
      $cpu_count++;
      last;
    }
  }
  $ret
}

open (CPUINFO, "cat /proc/cpuinfo |");

while (&get_next_cpu) {
  &count_cores;
}

close(CPUINFO);


# Calculate the total number of cores
foreach $cpu (keys(%cpus)) {
  $total_cores += $cpus{$cpu};
}

# parse the command line and see if a thread multiplier is set
# ignore any other options.
sub parse_command_line {
  while (@ARGV) {
    my($option) = shift(@ARGV);
    switch ($option) {
      case '--mult' {
        $thread_mult = shift(@ARGV);
      }
    }
  }
}

&parse_command_line();

$total_threads = $total_cores * $thread_mult;

print "$total_threads";
 
