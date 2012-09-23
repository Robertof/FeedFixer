#!/usr/bin/env perl
# HTML::Parser based module for doing some weird things :p
# currently built specifically for androidworld.pm module
package FeedFixer::RobParser;
use strict;
use warnings;
use base "HTML::Parser";
use FeedFixer::Utils;

my $tag_mode;
my $tag_array;

# internal stuff
my $is_our_man = 0;
my $div_depth  = 0;
# details on hierarchy based system:
# each time a new tag opens (see start subroutine) it pushes (even if it
# is not allowed) an entry to $tag_hierarchy.
# then we:
# - can check if there are non-allowed tags in the hierarchy
# - in the end() callback remove the closed element from hierarchy
# - print text(es) like a boss
# - other cool stuff which I'm too lazy to say

my $tag_hierarchy = [
    # "good_tag", "another_good_tag", "bad_tag"
];
my $article_txt;

sub set_tag_stuff
{
    my ($self, $mode, $arrayss) = @_;
    # blist 0 wlist 1
    $tag_mode = $mode;
    $tag_array = $arrayss;
}

sub clear
{
    ($tag_mode, $tag_array, $is_our_man, $div_depth, $tag_hierarchy, $article_txt) = (undef, undef, 0, 0, [], "");
}

sub get_final_text
{
    return $article_txt;
}

sub start
{
    my ($self, $tag, $attr, $attrseq, $origtext) = @_;
    if ($tag =~ /^div$/i and exists $attr->{"class"} and $attr->{"class"} eq "content-post")
    {
        $is_our_man = 1;
        $div_depth++;
    }
    elsif ($is_our_man)
    {
        push @{$tag_hierarchy}, $tag;
        # we got our man! now we need to get his sons :p
        return if not $self->check_tag ($tag);
        return if not $self->check_hierarchy();
        # okay, now WE have purified tags.
        # I have a special few exceptions to manage..
        # like div.
        # I'll explain that later. (ln 130)
        if ($tag =~ /^div$/i)
        {
            #return if ( ( exists $attr->{"class"} and $attr->{"class"} eq "playstore" ) );
            $div_depth++;
        }
        # replace text-align style values, because they are ugly on feeds
        $origtext =~ s/text-align:\s?(left|center|right|justified);?//i;
        $origtext =~ s/\s?style=""//i;
        $article_txt .= $origtext;
    }
}

sub check_tag
{
    return 
        (
         ( $tag_mode eq 0 && !FeedFixer::Utils->in_array ($_[1], $tag_array) )
          ||
         ( $tag_mode eq 1 &&  FeedFixer::Utils->in_array ($_[1], $tag_array) )
        );
}

sub check_hierarchy
{
    my $self = shift;
    for (my $i = (scalar (@{$tag_hierarchy}) - 1); $i >= 0; $i--)
    {
        return 0 if (!$self->check_tag (lc ($tag_hierarchy->[$i])));
    }
    return 1;
}

# searches for an element in an array and deletes it and the following ones
# note: it searches the array BACKWARDS
# example:
# $arr = [ "hello", "i", "am", "roberto", "and", "i", "am", "fine" ];
# $arr = find_and_destroy ("i", $arr);
# join (", ", @$arr) ==> hello, i, am, roberto, and
sub find_and_destroy
{
    my ($self, $elm, $arr) = @_;
    for (my $i = (scalar (@{$arr}) - 1); $i >= 0; $i--)
    {
        if (lc ($arr->[$i]) eq lc ($elm))
        {
            # remove element(s) o:
            splice (@{$arr}, $i); #, 1);
            # stop
            last;
        }
    }
    $arr;
}

sub text
{
    my ($self, $text) = @_;
    $text =~ s/\s\s+/ /g;
    $article_txt .= $text if ($is_our_man and $self->check_hierarchy());
}

sub end
{
    my ($self, $tag, $origtext) = @_;
    # here we check $div_depth var, because if we
    # have other divs and we set $is_our_men to 0
    # everything'll break.
    if ($tag =~ /^div$/i)
    {
        if ($div_depth > 1)
        {
            $div_depth--;
            #print $origtext;
        }
        else
        {
            $is_our_man = 0;
        }
    }
    if ($is_our_man)
    {
        $self->find_and_destroy ($tag, $tag_hierarchy);
    }
    if ($is_our_man && $self->check_tag ($tag))
    {
        $article_txt .= $origtext;
    }
}

1;
