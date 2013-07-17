### main pod documentation begin ###################

=head1 NAME

  Stash_Simple - 'hold' onto data whilst processing a 'multi-form' application (or anything
             else you can think of).

=head1 DESCRIPTION

When building applications that may have 'many' forms and where the user may go
backwards / forwards as required when entering 'details' it may be necessary to 
'hold' those details until they need to be processed (for a database update - for example).
This module can be used to 'store' data from a 'form' in a central store until it is 
required (uses the Storable module and the freeze / thaw methods to store / retrieve the data -
stored in a compact form).

Create a 'storage' table in your database :-
	create table storage (
		store_key
		store
	);

=head1 USAGE

  	use Stash_Simple;

  	# create the 'stash'
	my $stash = Stash_Simple->new($self->dbh);

	# check if a 'stash' cookie alredy exists - if it does use it else create a new one with a unique key ....
	$stash->{key} = $self->query->cookie('STASH_SIMPLE') || undef;  # this is CGI::Application specific
	unless ($stash->{key}) {
		$stash->{key} = $stash->calc_stash_key();
		my $cookie = $self->query->cookie (                         # CGI::Application - cookie stuff
			-name => 'TSMSTASH',
			-value => $stash->{key},
			-expires => '+1d'
		);
		$self->header_props( -cookie => $cookie );                  # this is CGI::Application specific

		$stash->stash_init;
	}

	.........

	# to add 'things' to the 'stash' - name / value pairs

	$stash->stash_add('branch', $cgi->param('branch'));
	$stash->stash_add('name', $cgi->param('name'));

	# to delete 'things' from the 'stash' - provide an array of the 'names' of the things you
	# want to remove

	$stash->stash_delete( [qw(branch name)] );

	to retrieve 'things' from the stash
	my $name = $stash->{name};

=head1 BUGS

None i'm aware of...

=head1 SUPPORT

use at own risk .....

=head1 AUTHOR

    rpillarblackberry@googlemail.com

    todo - create a proper makefile, allow users to choose the 
           type of serialization mechanism they wish to use etc.

=head1 COPYRIGHT

This program is free software licensed under the...

=head1 VERSION

15/06/2012  v1.000  

=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################

package Stash_Simple;

use strict;
use warnings;

use Data::Dumper;
use Storable qw(freeze thaw);
use DBI;

#################### subroutine header start ###################

=head2 new

 Usage     : my $stash = Stash_Simple->new($database_handle);
 Purpose   : creates / initializes the Stash_Simple object
 Returns   : A Stash_Simple object.
 Argument  : a 'database handle'
 Throws    : nothing
 Comment   : none.

See Also   : 

=cut

#################### subroutine header end ####################

sub new {
	my $class = shift;
	my $self = {};
	$self->{dbh} = shift;
	$self->{key} = undef;
	$self->{stash} = {};
	bless ($self, $class);
	return $self;
}

#################### subroutine header start ###################

=head2 stash_init

 Usage     : $stash->stash_init();
 Purpose   : initialize the stash 'db' - creates a row in the storage table
             with a 'key' and the 'frozen' stash structure
 Returns   : nothing.
 Argument  : none
 Throws    : nothing
 Comment   : only run this once !!!.

See Also   : 

=cut

#################### subroutine header end ####################

sub stash_init {
	my $self = shift;
	
	my $sth = $self->{dbh}->prepare('insert into storage (store_key, store) values( ?, ?)') ||
		die "DBI prepare failed - $DBI::errstr\n\n";

	my $frozen = freeze $self->{stash};
	$sth->execute($self->{key}, $frozen) ||
		die "DBI execute failed - $DBI::errstr\n\n";
	$sth->finish();
}

#################### subroutine header start ###################

=head2 stash_add

 Usage     : $stash->stash_add($name, $value);
 Purpose   : add a name / value pair to the stash
 Returns   : nothing.
 Argument  : the 'name' of the thing being added and its 'value'
 Throws    : nothing
 Comment   : also updates the database table to ensure that the current
             'stash' structure and what is stored are kept inline.

See Also   : 

=cut

#################### subroutine header end ####################

sub stash_add {
	my $self = shift;
	my $stash_key = shift;
	my $stash_value = shift;
	
	$self->{stash}->{$stash_key} = $stash_value;
	_update_stash($self);
}

#################### subroutine header start ###################

=head2 stash_delete

 Usage     : $stash->stash_delete($keys);
 Purpose   : delete the supplied 'names' from the stash
 Returns   : nothing.
 Argument  : the 'name' of the things being deleted - supplied as an
             array - $self->stash_delete( [qw(username address)] );
 Throws    : nothing
 Comment   : also updates the database table to ensure that the current
             'stash' structure and what is stored are kept inline.

See Also   : 

=cut

#################### subroutine header end #####################

sub stash_delete {
	my $self = shift;
	my $stash_keys = shift;

	delete @{$self->{stash}}{@{$stash_keys}};
	_update_stash($self);	
}

#################### subroutine header start ###################

=head2 stash_get

 Usage     : my $stash = $stash->stash_get();
 Purpose   : gets the current 'stash' from the database
 Returns   : the 'stash'
 Argument  : none
 Throws    : nothing
 Comment   : the 'stored' structured is 'thawed' so it can be
             assigned to a perl variable as required
See Also   : 

=cut

#################### subroutine header end #####################

sub stash_get {
	my $self = shift;

	my $sth = $self->{dbh}->prepare('select store from storage where store_key = ?') ||
		die "DBI prepare failed - $DBI::errstr\n\n";
	$sth->execute($self->{key}) ||
		die "DBI execute failed - $DBI::errstr\n\n";
	my ($frozen) = $sth->fetchrow_array();
	$sth->finish();

	return $self->{stash} = thaw $frozen;
}

#################### subroutine header start ###################

=head2 _update_stash

 Usage     : _update_stash($self);
 Purpose   : updates the storage table so that the appropriate 'row'
             matches the current contents of the 'stash'
 Returns   : nothing
 Argument  : $self
 Throws    : nothing
 Comment   : never call this method 
See Also   : 

=cut

#################### subroutine header end #####################

sub _update_stash {
	my $self = shift;

	my $sth = $self->{dbh}->prepare('update storage set store = ? where store_key = ?') ||
		die "DBI prepare failed - $DBI::errstr\n\n";
	my $frozen = freeze $self->{stash};
	$sth->execute($frozen, $self->{key}) ||
		die "DBI execute failed - $DBI::errstr\n\n";
	$sth->finish();
}

#-------------------------------------------------------------------------------

1;
