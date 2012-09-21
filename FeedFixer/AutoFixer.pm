#!/usr/bin/env perl
# AutoFixer for XML::{Feed,Tree}PP modules
# This changes the way XML::TreePP encodes things
# so that it uses CDATA instead of fuckin' entities
# which ruin everything.

package FeedFixer::AutoFixer;
use strict;
use warnings;
use XML::FeedPP;
use XML::TreePP;
use FeedFixer::Utils;
use File::Spec;

# this is a static module, so you can use it like
# FeedFixer::AutoFixer->method_you_need
my $feedpp_path;
my $treepp_path;

# the correct execution tree for this is:
# FeedFixer::Autofixer->clear_from_previous_execution()
# ->find_module_path()->patch_file()->clear_vars()
sub clear_from_previous_execution
{
    my $self = shift;
    # remove files in FeedFixer/XML/*
    opendir my $dir, "FeedFixer/XML/" or FeedFixer::Utils->d (
        "Cannot open ff/xml dir: ${!}"
    );
    my @files = readdir $dir;
    closedir $dir;
    return if (scalar (@files) <= 0);
    foreach (@files)
    {
        unlink File::Spec->catfile ("FeedFixer/XML/", $_);
    }
    $self;
}

sub find_module_path
{
    my $self = shift;
    # hack: just find %INC hash and find module path :3
    foreach my $module (keys %INC)
    {
        if ($module =~ /^XML\/(Tree|Feed)PP\.pm$/)
        {
            my $path = $INC{$module};
            $path =~ s/'/\\'/g;
            eval ( "\$" . lc ($1) . "pp_path = '" . $path . "';");
            if ($@) { FeedFixer::Utils->d ("Error: " . $@); }
        }
    }
    if (not $feedpp_path or not $treepp_path)
    {
        FeedFixer::Utils->d (
            "Error: cannot find XML::TreePP or XML::FeedPP paths"
        );
    }
    $self;
}

sub check_paths
{
    return ( $feedpp_path and $treepp_path );
}

sub patch_file
{
    my $self = shift;
    !$self->check_paths && FeedFixer::Utils->d ("Please run find_module_path() before");
    # open files and patch them
    # first patch: FeedPP.pm
    open FEEDPP, "<", $feedpp_path 
        || FeedFixer::Utils->d ("Cannot open ${feedpp_path} : ${!}");
    my $fpp_c; $fpp_c .= $_ while (<FEEDPP>);
    close FEEDPP;
    # assign new package name
    my $fpp_pkgname = "FeedFixer::XML::FeedPP";
    my $tpp_pkgname = "FeedFixer::XML::TreePP";
    # replace old one with the new
    $fpp_c =~ s/XML::FeedPP/$fpp_pkgname/g;
    $fpp_c =~ s/XML::TreePP/$tpp_pkgname/g;
    # we're done here
    # let's start with treepp
    # second patch: TreePP.pm
    open TREEPP, "<", $treepp_path
        || FeedFixer::Utils->d ("Cannot open ${treepp_path} : ${!}");
    my $tpp_c; $tpp_c .= $_ while (<TREEPP>);
    close TREEPP;
    # fix package names as usual
    $tpp_c =~ s/XML::FeedPP/$tpp_pkgname/g;
    $tpp_c =~ s/XML::TreePP/$tpp_pkgname/g;
    # now we need a more complex patch: the one to xml_escape
    my $patched_code = <<'EOF'
sub xml_escape {
    my $str = shift;
    return '' unless defined $str;
    if ($str =~ /(&(?!#(\d+;|x[\dA-Fa-f]+;))|<|>|'|")/)
    {
        $str =~ s/\]\]>/&#93;&#93;&gt;/;
        $str = "<![CDATA[" . $str . "]]>";
    }
    $str;
}

sub xml_unescape
EOF
;
    
    $tpp_c =~ s/sub xml_escape\s\{.+?sub xml_unescape/$patched_code/s;
    # patching done, we just need to push it now
    open FEEDPPW, ">", "FeedFixer/XML/FeedPP.pm"
        || FeedFixer::Utils->d ("Cannot open FF/XML/FeedPP.pm, ${!}");
    print FEEDPPW "${fpp_c}\n";
    close FEEDPPW;
    open TREEPPW, ">", "FeedFixer/XML/TreePP.pm"
        || FeedFixer::Utils->d ("Cannot open FF/XML/TreePP.pm, ${!}");
    print TREEPPW "${tpp_c}\n";
    close TREEPPW;
    # everything done ^^
    $self;
}

sub has_been_patched
{
    ( -e "FeedFixer/XML/FeedPP.pm" && -e "FeedFixer/XML/TreePP.pm" );
}

sub clear_vars
{
    ($feedpp_path, $treepp_path) = (undef, undef);
}
1;
