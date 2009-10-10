var locksmith_disabled_fields;
var locksmith_renewer;
var locksmith_retryer;
var locksmith_uri;
var locksmith_object_type;
var locksmith_object_id;

document.getElementsByClassName = function(class_name) {
    var docList = this.all || this.getElementsByTagName('*');
    var matchArray = new Array();

    /*Create a regular expression object for class*/
    var re = new RegExp("(?:^|\\s)"+class_name+"(?:\\s|$)");
    for (var i = 0; i < docList.length; i++) {
        if (re.test(docList[i].className) ) {
            matchArray[matchArray.length] = docList[i];
        }
    }
	return matchArray;
}

function lockEntry() {
	var form_elems = getByID('entry_form').elements;
	// need to populate this first so we can unlock properly even if we don't lock
	locksmith_disabled_fields = new Array();
	for (var i = 0; i < form_elems.length; i++) {
		if (form_elems[i].getAttribute('disabled')) {
			locksmith_disabled_fields[form_elems[i].name] = true;
		}
	}
	if (locksmith_override) {
		var conf_text = locksmith_author_only ? locksmith_override_author_only_text : locksmith_override_text;
		if (confirm(conf_text)) {
			unlockEntry();
			return;
		}
	}
	for (var i = 0; i < form_elems.length; i++) {
		disableField(form_elems[i]);
	}
	var ects = document.getElementsByClassName('field-buttons-formatting');
	for (var i = 0; i < ects.length; i++) {
		TC.addClassName(ects[i], 'hidden');
	}
	var pickers = document.getElementsByClassName('date-picker');
	for (var i = 0; i < pickers.length; i++) {
		TC.addClassName(pickers[i], 'hidden');
	}
	var buttons = document.getElementsByTagName('button');
	for (var i = 0; i < buttons.length; i++) {
		disableField(buttons[i]);
		setOpacity(buttons[i], '.5');
	}
	var fd_button_spans = document.getElementsByClassName('fd-group-button');
	for (var i = 0; i < fd_button_spans.length; i++) {
		TC.addClassName(fd_button_spans[i], 'hidden');
	}	
	App.bootstrap();
	app.categorySelector.close(getByID('close-category-selector1'));
	TC.addClassName(getByID('open-category-selector1'), 'hidden');
	TC.removeClassName(getByID('locksmith-msg'), 'hidden');
	clearInterval(locksmith_retryer);
	clearInterval(locksmith_renewer);
	if (!locksmith_read_only) {
		locksmith_retryer = setInterval('retryLock();', locksmith_retry_every + 1000 * 60);
	}
}

function unlockEntry() {
// this is necessary on override because the browser may have the disabled state of fields
// cached on a reload; we don't need to unhide other elements hidden by lockEntry()
	getByID('editor-content-toolbar').childNodes[1].style.display = 'block';
	var form_elems = getByID('entry_form').elements;
	for (var i = 0; i < form_elems.length; i++) {
		if (!locksmith_disabled_fields[form_elems[i].name]) {
			enableField(form_elems[i]);
		}
	}
	var buttons = document.getElementsByTagName('button');
	for (var i = 0; i < buttons.length; i++) {
		enableField(buttons[i]);
		setOpacity(buttons[i], 1);
	}
	TC.addClassName(getByID('locksmith-msg'), 'hidden');
	startRenewLock();
}

function lockTemplate() {
	if (locksmith_override) {
		if (confirm(locksmith_override_text)) {
			// this is necessary because the browser may have the disabled state
			// cached on a reload
			unlockTemplate();
			return;
		}
	}
	if (window.app.cpeList) {
		window.app.cpeList[0].toggleOff(false); // don't set a cookie
	}
	TC.addClassName(getByID('template-body-actions'), 'hidden');
	var form_elems = getByID('template-listing-form').elements;
	for (var i = 0; i < form_elems.length; i++) {
		disableField(form_elems[i]);
	}
	var buttons = document.getElementsByTagName('button');
	for (var i = 0; i < buttons.length; i++) {
		disableField(buttons[i]);
		setOpacity(buttons[i], '.5');
	}
	var create_link = document.getElementsByClassName('icon-create')[0];
	if (create_link) {
		TC.addClassName(create_link, 'hidden');
	}
	var delete_links = document.getElementsByClassName('delete-archive-link');
	for (var i = 0; i < delete_links.length; i++) {
		TC.addClassName(delete_links[i], 'hidden');
	}
	TC.removeClassName(getByID('locksmith-msg'), 'hidden');
	locksmith_retryer = setInterval('retryLock();', locksmith_retry_every + 1000 * 60);
}

function unlockTemplate() {
	var form_elems = getByID('template-listing-form').elements;
	for (var i = 0; i < form_elems.length; i++) {
		enableField(form_elems[i]);
	}
	var buttons = document.getElementsByTagName('button');
	for (var i = 0; i < buttons.length; i++) {
		enableField(buttons[i]);
		setOpacity(buttons[i], 1);
	}
	TC.addClassName(getByID('locksmith-msg'), 'hidden');
	startRenewLock();
}

function disableField(fld) {
	fld.setAttribute('disabled', 'disabled');
}

function enableField(fld) {
	fld.removeAttribute('disabled');
}

function setOpacity(elem, opacity) {
	elem.style.opacity = opacity;
	var op_n = parseFloat(opacity) * 100;
	elem.filter = 'alpha(opacity=' + op_n + ')';
}

function startRenewLock(uri, object_type, object_id) {
	clearInterval(locksmith_retryer);
	clearInterval(locksmith_renewer);
	locksmith_renewer = setInterval('renewLock();', locksmith_renew_every * 1000 * 60);
	TC.attachWindowEvent('unload', releaseLock);
}

function renewLock() {
	var param = '__mode=locksmith_renew_lock&object_type=' + locksmith_object_type + '&id=' + locksmith_object_id;
    var params = {
    	uri: locksmith_uri,
    	method: 'POST',
    	arguments: param,
    	load: function(c) {
    		if (!c.responseText) return;
			var resp;
			try {
				resp = eval('(' + c.responseText + ')');
			} catch(e) {
				alert("Error: invalid response");
				return;
			}
			if (resp.error) {
				alert(resp.error);
				return;
			}
			locksmith_locked_until = resp.result.result;
    	}
    };
    TC.Client.call(params);
}

function retryLock() {
	var param = '__mode=locksmith_retry_lock&object_type=' + locksmith_object_type + '&id=' + locksmith_object_id;
    var params = {
    	uri: locksmith_uri,
    	method: 'POST',
    	arguments: param,
    	load: function(c) {
    		if (!c.responseText) return;
			var resp;
			try {
				resp = eval('(' + c.responseText + ')');
			} catch(e) {
				alert("Error: invalid response");
				return;
			}
			if (resp.error) {
				alert(resp.error);
				return;
			}
			if (resp.result.got_lock) {
				if (confirm(locksmith_now_available_text)) {
					window.location = window.location + '&locksmith_enable=1';
				}
			}
    	}
    };
    TC.Client.call(params);
}

function releaseLock() {
	var param = '__mode=locksmith_release_lock&object_type=' + locksmith_object_type + '&id=' + locksmith_object_id + '&locked_until=' + locksmith_locked_until;
    var params = {
    	uri: locksmith_uri,
    	method: 'POST',
    	arguments: param,
    	load: function(c) { }
    };
    TC.Client.call(params);
}