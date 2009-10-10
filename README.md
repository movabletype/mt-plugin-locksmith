# Locksmith Plugin for Movable Type

Authors: Six Apart, Kevin Shay
Copyright 2009 Six Apart, Ltd.
License: Artistic, licensed under the same terms as Perl itself

## Overview

A plugin for Movable Type which prevents entries and templates from being edited by more than one user at the same time.

## Features

* Entry/page locking to a single editor, entry's author, or disabled.
* Template locking to a single editor or disabled.
* Configurable times for:
    * Lock duration when editing an object
    * Lock renewal when editing an object
    * Retry interval when viewing a locked entry
* Lock override for System Administrator and optional second role.
* All user messaging strings are configurable.

## Installation

1. Move the Locksmith plugin directory to the MT `plugins` directory.
2. Move the Locksmith mt-static directory to the `mt-static/plugins` directory.

Should look like this when installed:

    $MT_HOME/
        plugins/
            Locksmith/
        mt-static/
            plugins/
                Locksmith/

