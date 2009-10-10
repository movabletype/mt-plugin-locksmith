
package Locksmith::Tags;
use strict;
use Data::Dumper;

sub hdlr_entry_locking_author {
	my ($ctx, $args, $cond) = @_;
	return hdlr_locking_author('entry', $ctx, $args, $cond);
}

sub hdlr_template_locking_author {
	my ($ctx, $args, $cond) = @_;
	return hdlr_locking_author('template', $ctx, $args, $cond);
}

sub hdlr_locking_author {
	my ($object_type, $ctx, $args, $cond) = @_;
	my $obj = MT->model($object_type)->load($ctx->var('id')) || return '';
	my $lock = MT->model('objectlock')->is_locked($obj);
	return '' unless $lock;
	my $author = MT->model('author')->load($lock->author_id);
	my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    local $ctx->{__stash}{author} = $author;
	defined(my $out = $builder->build($ctx, $tokens, $cond))
		or return $ctx->error($builder->errstr);
	return $out;
}

sub hdlr_entry_if_author_only {
	my ($ctx, $args, $cond) = @_;
	my $entry = MT->model('entry')->load($ctx->var('id')) || return 0;
	my $config = MT->component('locksmith')->get_config_hash('blog:' . $ctx->stash('blog')->id);
	return 0 unless ($config->{entry_locking} && ($config->{entry_locking} == 2));
	return ($entry->author_id == MT->instance->user->id) ? 0 : 1;
}

sub hdlr_entry_if_read_only {
	my ($ctx, $args, $cond) = @_;
	my $entry = MT->model('entry')->load($ctx->var('id')) || return 0;
	my $app = MT->instance;
	my $perms = $app->permissions;
	if ($app->user->id != $entry->author_id) {
		if ($perms->has('edit_all_posts_read_only')
				&& !$perms->has('administer_blog')) {
			return 1;
		}
	}
	return 0;
}

1;
