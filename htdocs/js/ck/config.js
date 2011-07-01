﻿/*
 Copyright (c) 2003-2011, CKSource - Frederico Knabben. All rights reserved.
 For licensing, see LICENSE.html or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function(config){

	var ljItems = ['LJUserLink','Image'];
	if(top.Site.media_embed_enabled){
		ljItems.push('LJEmbedLink');
	}
	ljItems.push('LJPollLink', 'LJCutLink', 'LJCut', 'Table');

	config.language = 'ru';
	config.autoParagraph = false;
	config.customConfig = '';
	config.docType = '<!DOCTYPE html>';
	config.baseHref = '';
	config.plugins =
		'basicstyles,' +
		'bidi,' +
		'blockquote,' +
		'button,' +
		'clipboard,' +
		'colorbutton,' +
		//'colordialog,' +
		'contextmenu,' +
		'dialog,' +
		'div,' +
		//'elementspath,' +
		'enterkey,' +
		'entities,' +
		'filebrowser,' +
		//'find,' +
		//'flash,' +
		'font,' +
		'format,' +
		'forms,' +
		'horizontalrule,' +
		'htmldataprocessor,' +
		'iframedialog,' +
		'image,' +
		'indent,' +
		'justify,' +
		'keystrokes,' +
		'link,' +
		'list,' +
		'liststyle,' +
		//'maximize,' +
		//'newpage,' +
		'pagebreak,' +
		'pastefromword,' +
		'pastetext,' +
		//'popup,' +
		'preview,' +
		//'print,' +
		'removeformat,' +
		'resize,' +
		//'save,' +
		//'smiley,' +
		'showblocks,' +
		'showborders,' +
		'sourcearea,' +
		'stylescombo,' +
		'scayt,' +
		'table,' +
		'tabletools,' +
		'specialchar,' +
		'tab,' +
		'templates,' +
		'toolbar,' +
		'undo,' +
		'wysiwygarea,'/* +
		'wsc'*/;

	config.fullPage = false;
	config.startupOutlineBlocks = false;
	config.autoGrow_maxHeight = 400;
	config.defaultLanguage = 'en';
	config.contentsLangDirection = 'ltr';
	config.entities = true;
	config.entities_additional = '#39';
	config.entities_greek = true;
	config.entities_latin = true;
	config.fillEmptyBlocks = true;
	config.emailProtection = 'mt(NAME,DOMAIN,SUBJECT,BODY)';
	config.startupFocus = false;
	config.forcePasteAsPlainText = false;
	config.forceSimpleAmpersand = false;
	config.tabIndex = 1;
	config.tabSpaces = 2;
	config.startupShowBorders = false;
	config.toolbarStartupExpanded = true;
	config.toolbarCanCollapse = true;
	config.ignoreEmptyParagraph = true;
	config.baseFloatZIndex = 10000;
	config.htmlEncodeOutput = false;
	config.templates_replaceContent = true;
	config.toolbarLocation = 'top';
	config.toolbar_Full = [
		['Bold','Italic','Underline','Strike','TextColor','FontSize'],
		['Link', 'Unlink'],
		ljItems,
		['Outdent','Indent'],
		['UnorderedList','OrderedList','JustifyLeft','JustifyCenter','JustifyRight'],
		['Undo', 'Redo']
	];
	config.toolbar_Basic = [
		['Bold','Italic','-','OrderedList','UnorderedList','-','Link','Unlink','-','About']
	];
	config.toolbar = 'Full';
	config.enterMode = 'br';
	config.forceEnterMode = false;
	config.shiftEnterMode = 'p';
	config.keystrokes = [
		[ CKEDITOR.CTRL + 65 /*A*/, true ],
		[ CKEDITOR.CTRL + 67 /*C*/, true ],
		[ CKEDITOR.CTRL + 70 /*F*/, true ],
		[ CKEDITOR.CTRL + 83 /*S*/, true ],
		[ CKEDITOR.CTRL + 84 /*T*/, true ],
		[ CKEDITOR.CTRL + 88 /*X*/, true ],
		[ CKEDITOR.CTRL + 86 /*V*/, 'Paste' ],
		[ CKEDITOR.CTRL + 45 /*INS*/, true ],
		[ CKEDITOR.SHIFT + 45 /*INS*/, 'Paste' ],
		[ CKEDITOR.CTRL + 88 /*X*/, 'Cut' ],
		[ CKEDITOR.SHIFT + 46 /*DEL*/, 'Cut' ],
		[ CKEDITOR.CTRL + 90 /*Z*/, 'Undo' ],
		[ CKEDITOR.CTRL + 89 /*Y*/, 'Redo' ],
		[ CKEDITOR.CTRL + CKEDITOR.SHIFT + 90 /*Z*/, 'Redo' ],
		[ CKEDITOR.CTRL + 76 /*L*/, 'Link' ],
		[ CKEDITOR.CTRL + 73 /*I*/, 'Italic' ],
		[ CKEDITOR.CTRL + 85 /*U*/, 'Underline' ],
		[ CKEDITOR.CTRL + CKEDITOR.SHIFT + 83 /*S*/, 'Save' ],
		[ CKEDITOR.CTRL + CKEDITOR.ALT + 13 /*ENTER*/, 'FitWindow' ],
		[ CKEDITOR.SHIFT + 32 /*SPACE*/, 'Nbsp' ]
	];

	!window.opera && config.keystrokes.push([ CKEDITOR.CTRL + 66 /*B*/, 'Bold' ]);  // LIVEJOURNAL SPECIFIC, LJSUP-4442

	config.browserContextMenuOnCtrl = false;
	config.colorButton_colors = '000000,993300,333300,003300,003366,000080,333399,333333,800000,FF6600,808000,808080,008080,0000FF,666699,808080,FF0000,FF9900,99CC00,339966,33CCCC,3366FF,800080,999999,FF00FF,FFCC00,FFFF00,00FF00,00FFFF,00CCFF,993366,C0C0C0,FF99CC,FFCC99,FFFF99,CCFFCC,CCFFFF,99CCFF,CC99FF,FFFFFF';
	config.font_names = 'Arial;Comic Sans MS;Courier New;Tahoma;Times New Roman;Verdana';
	config.fontSize_sizes = 'smaller;larger;xx-small;x-small;small;medium;large;x-large;xx-large';
	config.disableObjectResizing = false;
	config.disableNativeTableHandles = true;
	config.format_tags = 'p;h1;h2;h3;h4;h5;h6;pre;address;div';
	config.bodyId = '';
	config.bodyClass = '';
	config.fontSize_defaultLabel = '';
	config.removeFormatTags = 'b,big,code,del,dfn,em,font,i,ins,kbd,q,samp,small,span,strike,strong,sub,sup,tt,u,var';
	config.removeFormatAttributes = 'class,style,lang,width,height,align,hspace,valign';
	config.stylesSet = [{
			name: 'Red Title',
			element : 'h3',
			styles : {
				color:'red'
			}
	}];
	config.coreStyles_bold = { element : 'b', overrides : 'strong' };
	config.coreStyles_italic = { element : 'i', overrides : 'em' };
	config.indentClasses = [];
	config.indentOffset = 40;
	config.indentUnit = 'px';

	// The following value defines which File Browser connector and Quick Upload
	// "uploader" to use. It is valid for the default implementaion and it is here
	// just to make this configuration file cleaner.
	// It is not possible to change this value using an external file or even
	// inline when creating the editor instance. In that cases you must set the
	// values of LinkBrowserURL, ImageBrowserURL and so on.
	// Custom implementations should just ignore it.
	var _FileBrowserLanguage = 'php';	// asp | aspx | cfm | lasso | perl | php | py
	var _QuickUploadLanguage = 'php';	// asp | aspx | cfm | lasso | perl | php | py

	// Don't care about the following two lines. It just calculates the correct connector
	// extension to use for the default File Browser (Perl uses "cgi").
	var _FileBrowserExtension = _FileBrowserLanguage == 'perl' ? 'cgi' : _FileBrowserLanguage;
	var _QuickUploadExtension = _QuickUploadLanguage == 'perl' ? 'cgi' : _QuickUploadLanguage;

	config.filebrowserImageBrowseLinkUrl = config.baseHref + 'filemanager/browser/default/browser.html?Connector=' + encodeURIComponent(config.baseHref + 'filemanager/connectors/' + _FileBrowserLanguage + '/connector.' + _FileBrowserExtension);
	config.filebrowserFlashBrowseUrl = config.baseHref + 'filemanager/browser/default/browser.html?Type=Flash&Connector=' + encodeURIComponent(config.baseHref + 'filemanager/connectors/' + _FileBrowserLanguage + '/connector.' + _FileBrowserExtension);
	config.filebrowserFlashUploadUrl = config.baseHref + 'filemanager/connectors/' + _QuickUploadLanguage + '/upload.' + _QuickUploadExtension + '?Type=Flash';
	config.filebrowserImageBrowseUrl = config.baseHref + 'filemanager/browser/default/browser.html?Type=Image&Connector=' + encodeURIComponent(config.baseHref + 'filemanager/connectors/' + _FileBrowserLanguage + '/connector.' + _FileBrowserExtension);
	//config.filebrowserImageUploadUrl = config.baseHref + 'filemanager/connectors/' + _QuickUploadLanguage + '/upload.' + _QuickUploadExtension + '?Type=Image';

	config.filebrowserWindowHeight = screen.height * 0.7;
	config.filebrowserWindowWidth = screen.width * 0.7;

	/*config.smiley_path = config.baseHref + 'images/smiley/msn/';
	config.smiley_images = ['regular_smile.gif','sad_smile.gif','wink_smile.gif','teeth_smile.gif','confused_smile.gif','tounge_smile.gif','embaressed_smile.gif','omg_smile.gif','whatchutalkingabout_smile.gif','angry_smile.gif','angel_smile.gif','shades_smile.gif','devil_smile.gif','cry_smile.gif','lightbulb.gif','thumbs_down.gif','thumbs_up.gif','heart.gif','broken_heart.gif','kiss.gif','envelope.gif'];
	config.smiley_columns = 8;*/

	config.dialog_backgroundCoverColor = '#ffffff';
	config.dialog_backgroundCoverOpacity = 0.50;

	config.extraPlugins = 'livejournal';
	config.protectedSource.push(/<lj-poll-\d+\s*\/?>/gi); // created lj polls;
	config.protectedSource.push(/<lj-replace name="first_post"\s*\/?>/gi);
	config.protectedSource.push(/<lj-repost\s*\/?>/gi);

};