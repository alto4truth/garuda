#!/usr/bin/env raku
use lib "lib";
use LLVM::Subset;
use LLVM::Subset::Analysis;

my $module = Module.new(:name("test.bc"));
my $func = $module.get-or-create-function("main");
say "Module: ", $module.name;
say "Functions: ", $module.size;

my $group = GroupDomain.new(:name("main"));
$group.set-top;
say "GroupDomain is-top: ", $group.is-top;

my $manager = GroupDomainManager.new();
my $tracked = $manager.get-or-create-group("main");
say "Tracked group name: ", $tracked.name;

my $interval = IntervalDomain.new(-10, 10);
say "Interval: [", $interval.get-lower, ", ", $interval.get-upper, "]";

my $tracker = ProgressUpdateTracker.new();
$tracker.record-update("x", 42);
say "Updates recorded: ", $tracker.get-update-count;

say "\nAll tests passed!";