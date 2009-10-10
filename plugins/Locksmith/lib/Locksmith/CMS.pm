
package Locksmith::CMS;
use strict;
use Data::Dumper;
use MT::Util qw( encode_js );

sub post_save_entry {
	my ($cb, $app, $entry) = @_;
}

sub source_edit_entry {
	my ($cb, $app, $template) = @_;
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $app->param('blog_id'));
	return unless ($config->{entry_locking});
	my $old = q{<mt:unless name="new_object">};
	my $new = _head_mtml('entry', $config);
	$$template =~ s/$old/$old$new/;
	$old = q{<div id="msg-block">};
	$new = qq{
		<mtapp:statusmsg
			id="locksmith-msg"
			class="info hidden">
			<mt:EntryIfAuthorOnly>
				$config->{author_only_text}
			<mt:Else>
				<mt:EntryIfReadOnly>
					$config->{read_only_text}
				<mt:Else>
					<mt:EntryLockingAuthor>
						$config->{locked_text}
					</mt:EntryLockingAuthor>
				</mt:EntryIfReadOnly>
			</mt:EntryIfAuthorOnly>
		</mtapp:statusmsg>
	};
	$$template =~ s/$old/$old$new/;
}

sub source_edit_template {
	my ($cb, $app, $template) = @_;
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $app->param('blog_id'));
	return unless ($config->{template_locking});
	my $old = q{<mt:setvarblock name="html_body" append="1">};
	my $new = _head_mtml('template', $config);
	$$template =~ s/$old/$old$new/;
	$old = q{<mt:setvarblock name="system_msg">};
	$new = qq{
		<mtapp:statusmsg
			id="locksmith-msg"
			class="info hidden">
			<mt:TemplateLockingAuthor>
				$config->{locked_text}
			</mt:TemplateLockingAuthor>
		</mtapp:statusmsg>
	};
	$$template =~ s/$old/$old$new/;
}

sub _head_mtml {
	my ($object_type, $config) = @_;
	my $func = 'lock' . ucfirst($object_type);
	return qq{
<mt:setvarblock name="html_head" append="1">
<script type="text/javascript" src="<mt:var name="static_uri">plugins/Locksmith/Locksmith.js"></script>
</mt:setvarblock>
<script type="text/javascript">
var locksmith_locked = <mt:if name="locksmith_locked">true<mt:else>false</mt:if>;
var locksmith_locked_until = <mt:var name="locksmith_locked_until">;
var locksmith_read_only = <mt:if name="locksmith_read_only">true<mt:else>false</mt:if>;
var locksmith_extended = <mt:if name="locksmith_extended">true<mt:else>false</mt:if>;
var locksmith_author_only = <mt:if name="locksmith_author_only">true<mt:else>false</mt:if>;
var locksmith_override = <mt:if name="locksmith_override">true<mt:else>false</mt:if>;
var locksmith_hold_for = <mt:var name="locksmith_hold_for">;
var locksmith_renew_every = <mt:var name="locksmith_renew_every">;
var locksmith_retry_every = <mt:var name="locksmith_retry_every">;
var locksmith_object_type = '<mt:var name="object_type">';
var locksmith_object_id = '<mt:var name="id">';
var locksmith_uri = '<mt:var name="script_url">';
var locksmith_override_text = '<mt:Section encode_js="1">$config->{override_text}</mt:Section>';
var locksmith_override_author_only_text = '<mt:Section encode_js="1">$config->{override_author_only_text}</mt:Section>';
var locksmith_read_only_text = '<mt:Section encode_js="1">$config->{read_only_text}</mt:Section>';
var locksmith_now_available_text = '<mt:Section encode_js="1">$config->{now_available_text}</mt:Section>';
if (locksmith_locked) {
	TC.attachLoadEvent($func);
} else {
	TC.attachLoadEvent(startRenewLock);
}
</script>
	};
}

sub param_edit_entry {
	my ($cb, $app, $param) = @_;
	return unless ($param->{id});
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $param->{blog_id});
	_set_params($param, $config);
	my $entry = MT->model('entry')->load($param->{'id'});
	my $perms = $app->permissions;
	if ($app->user->id != $entry->author_id) {
		if ($perms->has('edit_all_posts_read_only')
				&& !$perms->has('administer_blog')) {
			$param->{locksmith_locked} = 1;
			$param->{locksmith_read_only} = 1;
		} elsif ($config->{entry_locking} == 2) {
			# entry author only
			$param->{locksmith_locked} = 1;
			$param->{locksmith_author_only} = 1;
			my $author = MT->model('author')->load($entry->author_id);
			$param->{entry_author_name} = $author->name;
			$param->{entry_author_display_name} = $author->nickname;
			if (_can_override($app, $config)) {
				$param->{locksmith_override} = 1;
			}
		}
	}
	# only check for normal locking if not already locked based on author/perm
	if (!$param->{locksmith_locked} && ($config->{entry_locking} == 1)) {
		if (my $lock = MT->model('objectlock')->is_locked($entry)) {
			$param->{locksmith_locked} = 1;
			if (_can_override($app, $config)) {
				$param->{locksmith_override} = 1;
			}
		} else {
			my $lock = MT->model('objectlock')->set_lock($entry, $config->{hold_for});
			$param->{locksmith_locked_until} = $lock->locked_until;
		}
	}
}

sub param_edit_template {
	my ($cb, $app, $param) = @_;
	return unless ($param->{id});
	# need to account for global templates
	my $scope = $param->{blog_id} ? "blog:$param->{blog_id}" : 'system';
	my $config = MT->component('locksmith')->get_config_hash($scope);
	return unless ($config->{template_locking});
	my $template = MT->model('template')->load($param->{'id'});
	if (my $lock = MT->model('objectlock')->is_locked($template)) {
		$param->{locksmith_locked} = 1;
		$param->{locksmith_locked_until} = $lock->locked_until;
		if (_can_override($app, $config)) {
			$param->{locksmith_override} = 1;
		}
	} else {
		my $lock = MT->model('objectlock')->set_lock($template, $config->{hold_for});
		$param->{locksmith_locked_until} = $lock->locked_until;
	}
	_set_params($param, $config);
}

sub source_edit_role {
	my ($cb, $app, $template) = @_;
	my $old = q{<mt:var name="prompt-edit_all_posts" escape="html"></label>};
	my $new = q{
<div id="locksmith-perms"><input type="checkbox" name="permission" value="edit_all_posts_read_only" id="permission-edit_all_posts_read_only"<mt:if name="have_access-edit_all_posts_read_only"> checked="checked"</mt:if> <mt:unless name="have_access-edit_all_posts"> disabled="disabled"</mt:unless> /> Read-Only&nbsp;&nbsp;
</div>
	};
	$$template =~ s/\Q$old\E/$old$new/;
	$old = q#function on_edit_all_posts_changed(obj) {#;
	$new = <<HTML;
$old
	var eap = getByID('permission-edit_all_posts');
	var eapro = getByID('permission-edit_all_posts_read_only');
	if (eap && eap.checked) {
		eapro.disabled = false;
		if (eapro.checked) {
			eape.disabled = false;
		}
	} else {
		eapro.disabled = true;
		eapro.checked = false;
	}
HTML
	$$template =~ s/\Q$old\E/$new/;
}

sub _set_params {
	my ($param, $config) = @_;
	for my $key (qw( hold_for retry_every renew_every )) {
		$param->{'locksmith_' . $key} = $config->{$key};
	}
	$param->{locksmith_locked_until} ||= 0;
}

sub renew_lock {
	my ($app) = @_;
	my ($user) = $app->login;
	if (!$user) {
		return $app->json_error('Your login has expired. Please save your changes and sign in again.');
	}
	return $app->json_error('No object ID') unless $app->param('id');
	my $obj = MT->model($app->param('object_type') || 'entry')->load($app->param('id'));
	return $app->json_error('Object not found') unless $obj;
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $obj->blog_id);
	my $lock = MT->model('objectlock')->set_lock($obj, $config->{hold_for});
	return $app->json_result({ result => $lock->locked_until });
}

sub retry_lock {
	my ($app) = @_;
	my ($user) = $app->login;
	if (!$user) {
		return $app->json_error('Your login has expired. Please sign in again.');
	}
	return $app->json_error('No object ID') unless $app->param('id');
	my $obj = MT->model($app->param('object_type') || 'entry')->load($app->param('id'));
	return $app->json_error('Object not found') unless $obj;
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $obj->blog_id);
	if (my $lock = MT->model('objectlock')->is_locked($obj)) {
		return $app->json_result({ result => 'Still locked' });
	} else {
		MT->model('objectlock')->set_lock($obj, $config->{hold_for});
		return $app->json_result({ got_lock => 1 });
	}
}

sub release_lock {
	my ($app) = @_;
	# errors and result won't really go anywhere, since this is called onunload 
	return unless $app->param('id');
	my $obj = MT->model($app->param('object_type') || 'entry')->load($app->param('id'));
	return unless $obj;
	my $class = MT->model('objectlock');
	my $lock = $class->current_lock($obj);
	return unless $lock;
	return unless ($lock->author_id == $app->user->id);
	# if locked_until is different from what the browser has, that indicates that
	# the lock has been updated, so we don't want to expire it; this prevents
	# a race condition when the editing screen is reloaded
	return unless ($lock->locked_until == $app->param('locked_until'));
	$class->release_lock($obj);
}

sub _can_override {
	my ($app, $config) = @_;
	return 1 if ($app->user->is_superuser);
	return 0 unless $config->{override_role};
	my $role = MT->model('role')->load({ name => $config->{override_role} });
	return 0 unless $role;
	my %terms = (
		role_id => $role->id,
		author_id => $app->user->id,
		blog_id => $app->param('blog_id') || 0
	);
	return MT->model('association')->count(\%terms);
}

1;
