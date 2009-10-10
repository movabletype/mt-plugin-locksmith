
package Locksmith::Util;

use MT;
use Data::Dumper;
$Data::Dumper::Maxdepth = 99;

my $mt_apply_default_settings;

sub init_app {
    my ($app) = @_;
    
    local $SIG{__WARN__} = sub {};
    $mt_apply_default_settings = \&MT::Plugin::apply_default_settings;
    *MT::Plugin::apply_default_settings = \&apply_default_settings;
}

sub apply_default_settings {
	my ($plugin, $data, $scope_id) = @_;
	return &{$mt_apply_default_settings}(@_) unless ($plugin->id eq 'locksmith');
	return &{$mt_apply_default_settings}(@_) if ($scope_id eq 'system');
	my $sys;
	for my $key (keys %{$plugin->registry('settings')}) {
		next if exists($data->{$key});
			# don't load system settings unless we need to
		$sys ||= $plugin->get_config_obj('system')->data;
		$data->{$key} = $sys->{$key};
	}
}

1;
