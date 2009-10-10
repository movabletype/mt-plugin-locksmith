
package ObjectLock;
use strict;
use Data::Dumper;

use base qw( MT::Object );

__PACKAGE__->install_properties ({
    column_defs => {
        id => 'integer not null primary key auto_increment',
        object_id => 'integer not null',
        object_ds => 'string(20) not null',
        author_id => 'integer not null',
        locked_until => 'integer not null',
    },
    indexes => {
    	obj_id_ds => {
    		columns => [ 'object_id', 'object_ds' ], 
    	},
        author_id => 1,
    },
    audit       => 1,
    datasource  => 'objectlock',
    primary_key => 'id',
});

sub unixtime {
	my $class = shift;
	my $driver = $class->driver;
    my $unixtime_sql = $driver->dbd->sql_for_unixtime;
    return $driver->rw_handle->selectrow_array("SELECT $unixtime_sql");
}

sub is_locked {
	my $class = shift;
	my ($obj) = @_;
	my $app = MT->instance;
	my $unixtime = $class->unixtime;
	my %terms = (
		object_ds => $obj->datasource,
		object_id => $obj->id,
		locked_until => \">= $unixtime", #"
		author_id => { not => $app->user->id },
	);
	return $class->load(\%terms);
}

sub current_lock {
# return the current lock for an object, regardless of
# whether it's expired or whether the logged-in user owns it
	my $class = shift;
	my ($obj) = @_;
	my %terms = (
		object_ds => $obj->datasource,
		object_id => $obj->id,		
	);
	return $class->load(\%terms);
}

sub set_lock {
	my $class = shift;
	my ($obj, $hold_for) = @_;
	my %key_terms = (
		object_ds => $obj->datasource,
		object_id => $obj->id,
	);
	my %value_terms = (
		locked_until => $class->unixtime + ($hold_for * 60),
		author_id => MT->instance->user->id,
	);
	my $lock = $class->set_by_key(\%key_terms, \%value_terms);
	$lock->save || die $lock->errstr;
	return $lock;
}

sub release_lock {
	my $class = shift;
	my ($obj) = @_;
	# passing 0 as the hold_for value will cause it to expire immediately
	return $class->set_lock($obj, 0);
}

1;
