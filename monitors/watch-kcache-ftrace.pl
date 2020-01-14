#!/usr/bin/perl
# watch-kcache-ftrace - Print out stats on slab activity
# This script collects stats on slab activity using the ftrace
# function profiler. The intention is to build a picture of how
# slab-intensive a workload is based on the allocation/free frequency.

use strict;
use Time::HiRes qw( gettimeofday );

my $ftrace_prefix="/sys/kernel/debug/tracing";
my $exiting = 0;

sub write_value {
	my ($file, $value) = @_;

	open (SYSFS, ">$file") or die("Failed to open $file for writing");
	print SYSFS $value;
	close SYSFS
}

sub sigint_handler {
	$exiting = 1;
}
$SIG{INT} = "sigint_handler";

my $monitorInterval = $ENV{"MONITOR_UPDATE_FREQUENCY"};
if ($monitorInterval == 0) {
	$monitorInterval = 10;
}

# Configure ftrace to capture allocation latencies
write_value("$ftrace_prefix/set_ftrace_filter", "kmem_cache_alloc kmem_cache_alloc_node kmem_cache_free kmem_cache_alloc_trace kmem_cache_alloc_node_trace kfree");
write_value("$ftrace_prefix/current_tracer", "nop");
write_value("$ftrace_prefix/function_profile_enabled", "1");

while (!$exiting) {
        sleep($monitorInterval);

        my $total_allocs = 0;
        my $total_frees = 0;
        my $total_kmallocs = 0;
        my $total_kfrees = 0;

        my @files = <$ftrace_prefix/trace_stat/function*>;
        foreach my $file (@files) {
                open(my $fh, $file);
                while (my $line = <$fh>) {
                        if ($line =~ /(kmem_cache_alloc|kmem_cache_alloc_node)\s+(\d+)/) {
                                $total_allocs += $2;
                        }
                        if ($line =~ /kmem_cache_free\s+(\d+)/) {
                                $total_frees += $1;
                        }
                        if ($line =~ /(kmem_cache_alloc_trace|kmem_cache_alloc_node_trace)\s+(\d+)/) {
                                $total_kmallocs += $2;
                        }
                        if ($line =~ /kfree\s+(\d+)/) {
                                $total_kfrees += $1;
                        }
                }
            }

        printf("time: %d\n", gettimeofday());

        printf("  total kmem_cache_allocs %12d %12d/sec\n", $total_allocs,   $total_allocs / $monitorInterval);
        printf("  total kmem_cache_frees  %12d %12d/sec\n", $total_frees,    $total_frees  / $monitorInterval);
        printf("  total kmallocs          %12d %12d/sec\n", $total_kmallocs, $total_kmallocs / $monitorInterval);
        printf("  total kfrees            %12d %12d/sec\n", $total_kfrees,   $total_kfrees  / $monitorInterval);
        printf("\n");
}

write_value("$ftrace_prefix/function_profile_enabled", "0");
write_value("$ftrace_prefix/set_ftrace_filter", "");
