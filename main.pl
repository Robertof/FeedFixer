#!/usr/bin/env perl
# Robertof's Perl FeedFixer Main Script
# The main script needs modules to work properly.
# Everyone can write a module.
# Just see the default one in FeedFixer/androidworld.pm
# License: GNU/GPL v3

use strict;
use warnings;
use FeedFixer::Utils;
use File::Basename;
use POSIX qw(strftime);
my $VERSION = "1.0";

######################################
# BEGIN: Configuration               #
######################################
# Also you may want to see:          #
# FeedFixer/*.pm                     #
# for per-module configurations.     #
######################################
my $modules_enabled = [
    "androidworld"
]; # see FeedFixer/ folder
my $check_every     = 300; # check for new articles every X seconds
my $quiet           = 0;   # suppress script output?
my $log             = 1;   # enable logging?
my $log_path        = "feedfixer.log"; # where to save logs if $log == 1?
my $purge_log       = 1;   # purge log on start?
my $dump_path       = "feeds/%MODULENAME%.xml"; # where to save parsed feeds
######################################
# END:   Configuration               #
######################################

# Purge log if required
if ($purge_log)
{
    open FH, ">", $log_path or die "cannot open logfile, $!\n";
    close FH;
}
# Print some messages and hook modules
if (scalar @{$modules_enabled} eq 0)
{
    justLog ("Cannot initialize R's FFixer. No modules enabled in config.");
    print STDERR "Cannot initialize R'S FFixer. No modules enabled in config.\n";
    exit 1;
}
printAndLog ("Robertof's FeedFixer v${VERSION} started.");
printAndLog ("Options: the feedfixer will check every " . $check_every .
            " seconds new feeds from the module(s) "
            . join (", ", @$modules_enabled)
            . ". It w" . ($log ? "ill log output to ${log_path}" :
            "on't log anything") . ", and it will save 'fixed' feeds in '"
            . dirname ($dump_path) . "/'.");
printAndLog ("Initializing modules..");
my $total_modules = scalar @{$modules_enabled};
my %modules_reference;
my $inited_modules = 0;
foreach my $module (@{$modules_enabled})
{
    my $perc = ( 100 * $inited_modules ) / $total_modules;
    $module =~ s/[\.\/\\]//g;
    my $modref;
    if (exists $modules_reference{$module})
    {
        FeedFixer::Utils->d (
            sprintf ("Cannot load module %s: it already exists in modrefs",
            $module)
        );
    }
    eval "require FeedFixer::${module};";
    if ($@) {
        FeedFixer::Utils->d (
            sprintf ("Cannot load module %s: %s", $module, $@)
        );
    }
    eval "\$modref = FeedFixer::${module}->new();";
    if ($@) {
        FeedFixer::Utils->d (
            sprintf ("Cannot init module %s: %s", $module, $@)
        );
    }
    if (ref ($modref) ne "FeedFixer::${module}")
    {
        FeedFixer::Utils->d (
            sprintf ("Cannot init module %s, its reference != %s but %s",
            $module, "FeedFixer::${module}", ref ($modref))
        );
    }
    $modules_reference{$module} = $modref;
    justPrint (sprintf ("[%d%%] Module %s loaded.", $perc, $module));
    justLog   ("Loaded module ${module}.");
    $inited_modules++;
}
justPrint (sprintf ("[100%%] Loaded %d module(s).", $total_modules));
justLog   ("Loaded all modules.");
printAndLog ("Starting main loop.. Press Ctrl-C to stop.");
while (1)
{
    printAndLog ("Starting syncing..");
    foreach my $modname (keys %modules_reference)
    {
        printAndLog ("[${modname}] Syncing...");
        my $feed_text = $modules_reference{$modname}->getFeed();
        if ($feed_text eq -1)
        {
            FeedFixer::Utils->w ("Cannot sync ${modname}, skipping this module...");
            next;
        }
        printAndLog ("[${modname}] Syncing complete! Saving feed...");
        my $fname = $dump_path;
        $fname   =~ s/%MODULENAME%/$modname/gi;
        open DUMPFILE, ">", $fname or FeedFixer::Utils->w ("Failed saving file: ${!}");
        print DUMPFILE "${feed_text}\n";
        close DUMPFILE;
        printAndLog ("[${modname}] Feed saved in ${fname}. Proceeding...");
    }
    printAndLog ("Syncing complete. Waiting ${check_every} seconds..");
    sleep ($check_every);
}


sub printAndLog
{
    my $msg = shift;
    return if (!$log && $quiet); # avoid wasteful variables
    my $formattedTime = strftime "%d/%m/%Y @ %H:%M:%S", localtime;
    my $fMsg = sprintf "[%s] %s${/}", $formattedTime, $msg;
    # check if we should log
    if ($log)
    {
        open FH, ">>", $log_path or die "cannot open logfile, $!\n";
        # [18/09/2012 @ 12:39] message
        printf FH $fMsg;
        # close logfile
        close FH;
    }
    # check if we should print
    print $fMsg if not $quiet;
}

sub justLog
{
    my $msg = shift;
    return if not $log or not $msg;
    open FH, ">>", $log_path or die "cannot open logfile, $!\n";
    printf FH "[%s] %s${/}", (strftime "%d/%m/%Y @ %H:%M:%S", localtime), $msg;
    close FH;
}
        
sub justPrint
{
    my $msg = shift;
    return if $quiet;
    printf "[%s] %s${/}", (strftime "%d/%m/%Y @ %H:%M:%S", localtime), $msg;
}
