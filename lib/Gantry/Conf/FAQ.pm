package Gantry::Conf::FAQ; 

#####################################################################
# 
#  Name        :    Gantry::Conf::FAQ 
#  Author      :    Frank Wiles <frank@revsys.com> 
#
#  Description :    To be completed FAQ for Gantry::Conf 
#
#####################################################################


1;

__END__

=head1 NAME

Gantry::Conf::FAQ - Frequently Asked Questions regarding Gantry::Conf 

=over 4

=item Why should I use Gantry::Conf at all? 

There are many reasons why we feel Gantry::Conf is helpful both during
development and after deployment. The next two entries should hopefully
answer this quesiton for you as they outline a few common scenarios 
programmers and system administrators often face. 

=item How is Gantry::Conf helpful during development? 

=over 4 

=item Easy separation of development configs from production configs

Often programmers have a separate development environment from their
production environment.  By using <shared> blocks and dev instances you
can avoid spending any serious time setting up your application in the
development environment.  Take this configuration example: 

  <shared dev> 
     dbuser nobody
     dbpass secret
     dbconn "dbi:Pg:dbname=dev"
  </shared>

  <shared production>
     dbuser apache
     dbpass secret2
     dbconn "dbi:Pg:dbname=production"
  </shared> 

  <instance app1> 
     ConfigureVia FlatFile Config::General /etc/apps/app1.conf 
     use production 
  </instance> 

  <instance app1-dev> 
     ConfigureVia FlatFile Config::General /etc/apps/app1.conf 
     use dev
  </instance> 

By separating out our production and dev database information into shared
blocks we can essentially switch between our production and dev environments
by simplyl changing the instance we are using. If you were working on a script
this would be a simple matter of running: 

  $ script.pl --instance=app1-dev 

instead of: 

  $ script.pl --instance=app1 

=back 

=item How is Gatnry::Conf helpful in production? 

TODO 

=item How do I pass my instance information into my application? 

There are many possible ways to do this a few of which are: 

=over 4

=item Command line arguments 

If your application accepts arguments on the command line we suggest
adding an C<--instance> option to pass in the instance's name. 

=item PerlSetVar

In a mod_perl environment you could use a PerlSetVar, possibly named 
C<Instance>, to pull in this value for your application. 

=item ModPerl::ParamBuilder 

Again in a mod_perl environment, another option would be to use 
ModPerl::ParamBuilder to pass the instance name in. 

=item Hard coded 

We include this for the sake of completeness, but advise against it. You
could always simply hard code your instance information into your application,
but this will greatly reduce the flexibility you have. 

=back 

=item How do I add a different provider for an existing ConfigVia method?

TODO 

=item How do I add to the ConfigVia methods?

TODO 

=back 

=head1 SEE ALSO

Gantry(3), Gantry::Conf(3), Gantry::Conf::Tutorial(3)

=head1 AUTHOR

Frank Wiles <frank@revsys.com> 

=head1 COPYRIGHT and LICENSE

Copyright (c) 2006, Frank Wiles. 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut

