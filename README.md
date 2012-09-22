FeedFixer: feeds as you like 'em
-------------------------------

If you are tired of very truncated RSS feeds from websites, like:

<pre>.. first line of text .. (click here to go to the website)</pre>

Then FeedFixer is what do you need. As you may know, those kinds of feeds are very inconvenient for mobile phones. This script fixes the problem, creating a patched RSS file with all the text you need.

FAQ
-------------------------------

1.  **How does it work?**
    It takes the original feed from the original page and it fetches and parses its articles to get their full text. Then a patched RSS file is created.
2.  **How to use this?**
    Actually this script isn't much user-friendly, you need to manually configure the 'main.pl' file and the modules from the FeedFixer/ directory. Comments are there to help you.
3.  **What do I need to run this?**
    Perl, XML::FeedPP, XML::TreePP (included in XML::FeedPP), File::Basename, File::Spec, HTML::Parser, Digest::MD5 and IO::Socket::INET.
4.  **Okay, I have started the program but.. where are my feeds!?**
    First: this script needs MODULES. For each site. For now there are only few default modules. By the way, the script dumps the fixed feed in the 'feeds/' directory by default. Check its output if you think something went wrong.
5.  ~~**What is the FeedFixer::AutoFixer module, and why it does save XML::TreePP and XML::FeedPP in my FeedFixer/XML/ folder?**~~
    ~~This module is used to patch XML::TreePP and XML::FeedPP xml_escape() function, as it contained some things I didn't like (actually - too long to explain). You can see the module source if you don't trust me.~~ Removed, it was causing a lot of problems.
6.  **The logfile is too big!!**
    Well, loglevel is a thing I'll add in future releases.
7.  **I need a module for XXX.com, C'MON!!!**
    Calm down and open an issue.
8.  **Which license did you use for this?**
    GNU/GPL v3, but I'm too lazy to add headers and license files.
9.  **Why are you writing this FAQs if you know that no one will use you script?**
    Just for fun.
10. **What are the available modules?**
    For now, just AndroidWorld. I'll add other modules if you want, just say me the site.

Planned features
-------------------------------

1.  Threading for sync processes.
2.  Better error management.
3.  More modules!
4.  ~~Find a solution to avoid the autofixer.~~ Done.
5.  Log levels.

Okay, that's all. Now that you know how to use this, just.. have fun! :)
