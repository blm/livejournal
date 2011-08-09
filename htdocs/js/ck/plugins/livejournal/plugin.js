(function(){

	var likeButtons = [
		{
			label: top.CKLang.LJLike_button_facebook,
			id: 'facebook',
			abbr: 'fb',
			html: '<span class="lj-like-item lj-like-gag fb">' + top.CKLang.LJLike_button_facebook + '</span>',
			htmlOpt: '<li class="like-fb"><input type="checkbox" id="like-fb" /><label for="like-fb">' + top.CKLang
				.LJLike_button_facebook + '</label></li>'
		},
		{
			label: top.CKLang.LJLike_button_twitter,
			id: 'twitter',
			abbr: 'tw',
			html: '<span class="lj-like-item lj-like-gag tw">' + top.CKLang.LJLike_button_twitter + '</span>',
			htmlOpt: '<li class="like-tw"><input type="checkbox" id="like-tw" /><label for="like-tw">' + top.CKLang
				.LJLike_button_twitter + '</label></li>'
		},
		{
			label: top.CKLang.LJLike_button_google,
			id: 'google',
			abbr: 'go',
			html: '<span class="lj-like-item lj-like-gag go">' + top.CKLang.LJLike_button_google + '</span>',
			htmlOpt: '<li class="like-go"><input type="checkbox" id="like-go" /><label for="like-go">' + top.CKLang
				.LJLike_button_google + '</label></li>'
		},
		{
			label: top.CKLang.LJLike_button_vkontakte,
			id: 'vkontakte',
			abbr: 'vk',
			html: '<span class="lj-like-item lj-like-gag vk">' + top.CKLang.LJLike_button_vkontakte + '</span>',
			htmlOpt: window.isSupUser ? '<li class="like-vk"><input type="checkbox" id="like-vk" /><label for="like-vk">' + top.CKLang
				.LJLike_button_vkontakte + '</label></li>' : ''
		},
		{
			label: top.CKLang.LJLike_button_give,
			id: 'livejournal',
			abbr: 'lj',
			html: '<span class="lj-like-item lj-like-gag lj">' + top.CKLang.LJLike_button_give + '</span>',
			htmlOpt: '<li class="like-lj"><input type="checkbox" id="like-lj" /><label for="like-lj">' + top.CKLang
				.LJLike_button_give + '</label></li>'
		}
	];
	
	var note;

	var ljNoteData = {
		LJPollLink: {
			html: encodeURIComponent(top.CKLang.Poll_PollWizardNotice + '<br /><a href="#">' + top.CKLang.Poll_PollWizardNoticeLink + '</a>')
		},
		LJLike: {
			html: encodeURIComponent(top.CKLang.LJLike_WizardNotice + '<br /><a href="#">' + top.CKLang.LJLike_WizardNoticeLink + '</a>')
		},
		LJUserLink: {
			html: encodeURIComponent(top.CKLang.LJUser_WizardNotice + '<br /><a href="#">' + top.CKLang.LJUser_WizardNoticeLink + '</a>')
		},
		LJLink: {
			html: encodeURIComponent(top.CKLang.LJLink_WizardNotice + '<br /><a href="#">' + top.CKLang.LJLink_WizardNoticeLink + '</a>')
		},
		LJImage: {
			html: encodeURIComponent(top.CKLang.LJImage_WizardNotice + '<br /><a href="#">' + top.CKLang.LJImage_WizardNoticeLink + '</a>')
		},
		LJCut :{
			html: encodeURIComponent(top.CKLang.LJCut_WizardNotice + '<br /><a href="#">' + top.CKLang.LJCut_WizardNoticeLink + '</a>')
		}
	};

	var ljUsers = {};
	var currentNoteNode;

	CKEDITOR.plugins.add('livejournal', {
		init: function(editor){
			function onFindCmd(evt){
				var cmd;
				
				if(evt.name == 'mouseout'){
					note.hide();
					return;
				}

				var isMouseOver = evt.name == 'mouseover';
				var node = isMouseOver ? evt.data.getTarget() : editor.getSelection().getStartElement();
				var actNode;

				while(node){

					if(!attr){
						if(node.is('img')){
							node.setAttribute('lj-cmd', 'LJImage');
						} else if(node.is('a')){
							node.setAttribute('lj-cmd', 'LJLink');
						}
					}

					var attr = node.getAttribute('lj-cmd');

					if(attr){
						cmd = attr;
						actNode = node;
					}
					node = node.getParent();
				}

				if(cmd && ljNoteData.hasOwnProperty(cmd)){
					if(!isMouseOver){
						ljNoteData[cmd].node = actNode;
					}
					note.show(ljNoteData[cmd].html, cmd, actNode);
				} else {
					note.hide();
				}
			}

			editor.dataProcessor.toHtml = function(html, fixForBody){
				html = html.replace(/<((?!br)[^\s>]+)([^\/>]+)?\/>/gi, '<$1$2></$1>')
					.replace(/<lj-template name=['"]video['"]>(\S+?)<\/lj-template>/g, '<div class="ljvideo" url="$1"><img src="' + Site
					.statprefix + '/fck/editor/plugins/livejournal/ljvideo.gif" /></div>')
					.replace(/<lj-embed\s*(?:id="(\d*)")?\s*>([\s\S]*?)<\/lj-embed>/gi, '<div class="ljembed" embedid="$1">$2</div>')
					.replace(/<lj-poll .*?>[^b]*?<\/lj-poll>/gm,
					function(ljtags){
						return new Poll(ljtags).outputHTML();
					}).replace(/<lj-template(.*?)><\/lj-template>/g, "<lj-template$1 />");

				html = html.replace(/<lj-cut([^>]*)><\/lj-cut>/g, '<lj-cut$1>\ufeff</lj-cut>')
					.replace(/(<lj-cut[^>]*>)/g, '\ufeff$1').replace(/(<\/lj-cut>)/g, '$1\ufeff');

				// IE custom tags. http://msdn.microsoft.com/en-us/library/ms531076%28VS.85%29.aspx
				if(CKEDITOR.env.ie){
					html = html.replace(/<lj-cut([^>]*)>/g, '<lj:cut$1>').replace(/<\/lj-cut>/g, '</lj:cut>')
						.replace(/<([\/])?lj-raw>/g, '<$1lj:raw>').replace(/<([\/])?lj-wishlist>/g, '<$1lj:wishlist>')
						.replace(/(<lj [^>]*)> /g, '$1> '); // IE merge spaces
				} else {
					// close <lj user> tags
					html = html.replace(/(<lj [^>]*[^\/])>/g, '$1/> ');
				}
				if(!$('event_format').checked){
					html = '<pre>' + html + '</pre>';
				}

				html = CKEDITOR.htmlDataProcessor.prototype.toHtml.call(this, html, fixForBody);

				if(!$('event_format').checked){
					html = html.replace(/<\/?pre>/g, '');
					html = html.replace(/\n/g, '<br\/>');
				}

				return html;
			};

			editor.dataProcessor.toDataFormat = function(html, fixForBody){
				// DOM methods are used for detection of node opening/closing
				/*var document = editor.document.$;
				 var newBody = document.createElement('div'),
				 copyNode = document.body.firstChild;
				 if(copyNode){
				 newBody.appendChild(copyNode.cloneNode(true));
				 while(copyNode = copyNode.nextSibling){
				 newBody.appendChild(copyNode.cloneNode(true));
				 }
				 var divs = newBody.getElementsByTagName('div'),
				 i = divs.length;
				 while(i--){
				 var div = divs[i];
				 switch(div.className){
				 // lj-template any name: <lj-template name="" value="" alt="html code"/>
				 case 'lj-template':
				 var name = div.getAttribute('name'),
				 value = div.getAttribute('value'),
				 alt = div.getAttribute('alt');
				 if(!name || !value || !alt){
				 break;
				 }
				 var ljtag = FCK.EditorDocument.createElement('lj-template');
				 ljtag.setAttribute('name', name);
				 ljtag.setAttribute('value', value);
				 ljtag.setAttribute('alt', alt);
				 div.parentNode.replaceChild(ljtag, div);
				 }

				 }
				 }*/
				html = html.replace(/^<pre>\n*([\s\S]*?)\n*<\/pre>\n*$/, '$1');

				html = CKEDITOR.htmlDataProcessor.prototype.toDataFormat.call(this, html, fixForBody);

				html = html.replace(/\t/g, ' ');
				html = html.replace(/>\n\s*(?!\s)([^<]+)</g, '>$1<');
				if(!CKEDITOR.env.ie){
					html = html.replace(/<br (type="_moz" )? ?\/>$/, '');
					if(CKEDITOR.env.webkit){
						html = html.replace(/<br type="_moz" \/>/, '');
					}
				}

				html = html.replace(/<form.*?class="ljpoll" data="([^"]*)"[\s\S]*?<\/form>/gi,
					function(form, data){
						return unescape(data);
					}).replace(/<\/lj>/g, '');

				html = html
					.replace(/<div(?=[^>]*class="ljvideo")[^>]*url="(\S+)"[^>]*><img.+?\/><\/div>/g, '<lj-template name="video">$1</lj-template>')
					.replace(/<div(?=[^>]*class="ljvideo")[^>]*url="\S+"[^>]*>([\s\S]+?)<\/div>/g, '<p>$1</p>')
					.replace(/<div class=['"]ljembed['"](\s*embedid="(\d*)")?\s*>([\s\S]*?)<\/div>/gi, '<lj-embed id="$2">$3</lj-embed>')
					.replace(/<div\s*(embedid="(\d*)")?\s*class=['"]ljembed['"]\s*>([\s\S]*?)<\/div>/gi, '<lj-embed id="$2">$3</lj-embed>')// convert qotd
					.replace(/<div([^>]*)qotdid="(\d+)"([^>]*)>[^\b]*<\/div>(<br \/>)*/g, '<lj-template id="$2"$1$3 /><br />')// div tag and qotdid attrib
					.replace(/(<lj-template id="\d+" )([^>]*)class="ljqotd"?([^>]*\/>)/g, '$1name="qotd" $2$3')// class attrib
					.replace(/(<lj-template id="\d+" name="qotd" )[^>]*(lang="\w+")[^>]*\/>/g, '$1$2 \/>'); // lang attrib

				if(!$('event_format').checked && !top.switchedRteOn){
					html = html.replace(/\n?\s*<br \/>\n?/g, '\n');
				}

				// IE custom tags
				if(CKEDITOR.env.ie){
					html = html.replace(/<lj:cut([^>]*)>/g, '<lj-cut$1>').replace(/<\/lj:cut>/g, '</lj-cut>')
						.replace(/<([\/])?lj:wishlist>/g, '<$1lj-wishlist>').replace(/<([\/])?lj:raw>/g, '<$1lj-raw>');
				}

				html = html.replace(/><\/lj-template>/g, '/>');// remove null pointer.replace(/\ufeff/g, '');

				return html;
			};

			function addLastTag(){
				var body = editor.document.getBody();
				var last = body.getLast();
				if(last && last.type == 1 && !last.is('br')){
					body.appendHtml('<br />');
				}
			}

			editor.on('dataReady', function(){

				editor.document.on('mouseover', onFindCmd);
				editor.document.on('mouseout', onFindCmd);
				editor.document.on('keyup', onFindCmd);
				editor.document.on('click', onFindCmd);

				editor.document.on('keyup', addLastTag);
				editor.document.on('click', addLastTag);

				if(!note){
					var timer,
						state,
						currentData = {},
						tempData = {},
						noteNode = document.createElement('lj-note'),
						isIE = typeof(document.body.style.opacity) != 'string';

					var animate = (function(){
						var
							fps = 60,
							totalTime = 100,
							steps = totalTime * fps / 1000,
							timeOuts = [],
							type,
							parentContainer = document.getElementById('draft-container') || document.body;

						function apply(){
							var data = timeOuts.shift();
							var currentStep = (type ? data.time / totalTime : -(data.time / totalTime - 1)).toFixed(1);

							if(!timeOuts.length){
								currentStep = type ? 1 : 0;
							}

							if(isIE){
								noteNode.style.filter = (currentStep >= 1) ? null : 'progid:DXImageTransform.Microsoft.Alpha(opacity=' + (currentStep * 100) + ')';
							} else {
								noteNode.style.opacity = currentStep;
							}

							if(currentStep == 0 && noteNode && noteNode.parentNode){
								noteNode.parentNode.removeChild(noteNode);
							}
						}

						return function(animateType){
							type = animateType;

							if(type && noteNode.parentNode){
								if(isIE){
									noteNode.style.filter = null;
								} else {
									noteNode.style.opacity = 1;
								}
							} else {
								for(var i = 1; i <= steps; i++){
									var time = Math.floor(1000 / fps) * i;
									timeOuts.push({
										time: time,
										timer: setTimeout(apply, time)
									});
								}
							}

							parentContainer.appendChild(noteNode);
							noteNode.style.marginTop = -noteNode.offsetHeight / 2 + 'px';
							noteNode.style.marginLeft = -noteNode.offsetWidth / 2 + 'px';
						}
					})();

					noteNode.className = 'note-popup';
					
					noteNode.onmouseout = function(){
						if(!currentData.cmd) {
							note.hide();
						}
					};

					noteNode.onmouseover = function(){
						if(timer && !state){
							state = 1;
							clearTimeout(timer);
							timer = null;
						}
					};

					if(isIE){
						noteNode.style.filter = 'progid:DXImageTransform.Microsoft.Alpha(opacity=0)';
					} else {
						noteNode.style.opacity = 0;
					}

					function callCmd(){
						if(currentData.cmd){
							currentNoteNode = ljNoteData[currentData.cmd].node = currentData.node;
							editor.getCommand(currentData.cmd).exec();
						}
						return false;
					}

					function applyNote(){
						if(state){
							currentData.cmd = tempData.cmd;
							currentData.data = tempData.data;
							currentData.node = tempData.node;

							delete tempData.node;
							delete tempData.cmd;
							delete tempData.data;

							noteNode.innerHTML = decodeURIComponent(currentData.data);

							var link = noteNode.getElementsByTagName('a')[0];
							if(link && currentData.cmd){
								link.onclick = callCmd;
							}
						} else {
							delete currentData.node;
							delete currentData.cmd;
							delete currentData.data;

							currentNoteNode = null;
						}

						animate(state);

						timer = null;
					}

					note = {
						show: function(data, cmd, node){
							if(data == tempData.data && cmd == tempData.cmd && node === tempData.node){
								return;
							}

							if(timer){
								clearTimeout(timer);
								timer = null;
							}

							state = 1;
							timer = setTimeout(applyNote, 1000);
							
							tempData.data = data;
							tempData.cmd = cmd;
							tempData.node = node;
						},
						hide: function(isNow){
							if(state){
								state = 0;

								if(timer){
									clearTimeout(timer);
									timer = null;
								}

								if(noteNode.parentNode){
									isNow === true ? applyNote() : timer = setTimeout(applyNote, 500);
								}
							}
						}
					};
				}

			});

			//////////  LJ User Button //////////////
			var url = top.Site.siteroot + '/tools/endpoints/ljuser.bml';

			editor.attachStyleStateChange(new CKEDITOR.style({
				element: 'span'
			}), function(){
				var selectNode = editor.getSelection().getStartElement().getAscendant('span', true);
				var isUserLink = selectNode && selectNode.hasClass('ljuser');
				ljNoteData.LJUserLink.node = isUserLink ? selectNode : null;
				editor.getCommand('LJUserLink').setState(isUserLink ? CKEDITOR.TRISTATE_ON : CKEDITOR.TRISTATE_OFF);
			});

			editor.on('doubleclick', function(evt){
				var command = editor.getCommand('LJUserLink');
				if(command.state == CKEDITOR.TRISTATE_ON){
					command.exec();
				}

				evt.data.dialog = '';
			});

			editor.addCommand('LJUserLink', {
				exec : function(editor){
					var userName = '',
						selection = editor.getSelection(),
						LJUser = ljNoteData.LJUserLink.node;

					if(ljNoteData.LJUserLink.node){
						userName = prompt(top.CKLang.UserPrompt, ljNoteData.LJUserLink.node.getElementsByTag('b').getItem(0).getText());
					} else if(selection.getType() == 2){
						userName = selection.getSelectedText();
					}

					if(userName == ''){
						userName = prompt(top.CKLang.UserPrompt, userName);
					}

					if(!userName){
						return;
					}

					parent.HTTPReq.getJSON({
						data: parent.HTTPReq.formEncoded({
							username : userName
						}),
						method: 'POST',
						url: url,
						onData: function(data){
							if(data.error){
								alert(data.error);
								return;
							}
							if(!data.success){
								return;
							}
							data.ljuser = data.ljuser.replace('<span class="useralias-value">*</span>', '');

							ljUsers[userName] = data.ljuser;

							var tmpNode = editor.document.createElement('div');
							tmpNode.setHtml(data.ljuser);
							ljNoteData.LJUserLink.node = tmpNode.getFirst();
							ljNoteData.LJUserLink.node.setAttribute('lj-cmd', 'LJUserLink');

							if(LJUser){
								LJUser.$.parentNode.replaceChild(ljNoteData.LJUserLink.node.$, LJUser.$);
							} else {
								editor.insertElement(ljNoteData.LJUserLink.node);
							}
						}
					});
				}
			});

			editor.ui.addButton('LJUserLink', {
				label: top.CKLang.LJUser,
				command: 'LJUserLink'
			});

			//////////  LJ Image Button //////////////
			editor.addCommand('LJImage', {
				exec : function(editor){
					if(window.ljphotoEnabled){
						// call LJImage
					} else {
						if(ljNoteData.LJImage.node){
							editor.getSelection().selectElement(ljNoteData.LJImage.node);
						}
						editor.getCommand('image').exec();
					}
				}
			});

			editor.attachStyleStateChange(new CKEDITOR.style({
				element: 'img'
			}), function(state){
				if(state == CKEDITOR.TRISTATE_OFF && !currentNoteNode){
					delete ljNoteData.LJImage.node;
				}
				editor.getCommand('LJImage').setState(state);
			});

			editor.on('doubleclick', function(evt){
				var command = editor.getCommand('LJImage');
				if(command.state == CKEDITOR.TRISTATE_ON){
					command.exec();
				}

				evt.data.dialog = '';
			});

			editor.ui.addButton('LJImage', {
				label: editor.lang.common.imageButton,
				command: 'LJImage'
			});

			//////////  LJ Link Button //////////////
			editor.addCommand('LJLink', {
				exec : function(editor){
					if(ljNoteData.LJLink.node){
						editor.getSelection().selectElement(ljNoteData.LJLink.node);
					}
					editor.getCommand('link').exec();
				}
			});

			editor.attachStyleStateChange(new CKEDITOR.style({
				element: 'a'
			}), function(state){
				if(state == CKEDITOR.TRISTATE_OFF && !currentNoteNode){
					delete ljNoteData.LJLink.node;
				}
				editor.getCommand('LJLink').setState(state);
			});

			editor.on('doubleclick', function(evt){
				var command = editor.getCommand('LJLink');
				if(command.state == CKEDITOR.TRISTATE_ON){
					command.exec();
				}

				evt.data.dialog = '';
			});

			editor.ui.addButton('LJLink', {
				label: editor.lang.link.tollbar,
				command: 'LJLink'
			});

			//////////  LJ Embed Media Button //////////////
			editor.addCommand('LJEmbedLink', {
				exec: function(){
					top.LJ_IPPU.textPrompt(top.CKLang.LJEmbedPromptTitle, top.CKLang.LJEmbedPrompt, doEmbed, {
						width: '350px'
					});
				}
			});

			editor.ui.addButton('LJEmbedLink', {
				label: top.CKLang.LJEmbed,
				command: 'LJEmbedLink'
			});

			editor.addCss('img.lj-embed' + '{' + 'background-image: url(' + CKEDITOR.getUrl(this
				.path + 'images/placeholder_flash.png') + ');' + 'background-position: center center;' + 'background-repeat: no-repeat;' + 'border: 1px solid #a9a9a9;' + 'width: 80px;' + 'height: 80px;' + '}');

			function doEmbed(content){
				if(content && content.length){
					if(switchedRteOn){
						editor.insertHtml('<div class="ljembed">' + content + '</div><br/>');
					}
				}
			}

			//////////  LJ Cut Button //////////////
			editor.attachStyleStateChange(new CKEDITOR.style({
				element: 'lj-cut'
			}), function(state){
				if(state == CKEDITOR.TRISTATE_OFF && !currentNoteNode){
					delete ljNoteData.LJCut.node;
				}
				editor.getCommand('LJCut').setState(state);
			});

			editor.on('doubleclick', function(evt){
				var command = editor.getCommand('LJCut');
				if(command.state == CKEDITOR.TRISTATE_ON){
					command.exec();
				}
			});

			editor.addCommand('LJCut', {
				exec: function(){
					var text;
					if(ljNoteData.LJCut.node){
						text = prompt(top.CKLang.CutPrompt, ljNoteData.LJCut.node.getAttribute('text') || top.CKLang.ReadMore);
						if(text){
							if(text == top.CKLang.ReadMore){
								ljNoteData.LJCut.node.removeAttribute('text');
							} else {
								ljNoteData.LJCut.node.setAttribute('text', text);
							}
						}
					} else {
						text = prompt(top.CKLang.CutPrompt, top.CKLang.ReadMore);
						if(text){
							ljNoteData.LJCut.node = editor.document.createElement('lj-cut');
							ljNoteData.LJCut.node.setAttribute('lj-cmd', 'LJCut');
							if(text != top.CKLang.ReadMore){
								ljNoteData.LJCut.node.setAttribute('text', text);
							}
							editor.getSelection().getRanges()[0].extractContents().appendTo(ljNoteData.LJCut.node);
							editor.insertElement(ljNoteData.LJCut.node);
							var range = new CKEDITOR.dom.range(editor.document);
							range.selectNodeContents(ljNoteData.LJCut.node);
							editor.getSelection().selectRanges([range]);
						}
					}
				}
			});

			editor.ui.addButton('LJCut', {
				label: top.CKLang.LJCut,
				command: 'LJCut'
			});

			//////////  LJ Poll Button //////////////
			if(top.canmakepoll){
				var currentPoll;

				editor.attachStyleStateChange(new CKEDITOR.style({
					element: 'form',
					attributes: {
						'class': 'ljpoll'
					}
				}), function(state){
					if(state == CKEDITOR.TRISTATE_OFF && !currentNoteNode){
						delete ljNoteData.LJPollLink.node;
					}
					editor.getCommand('LJPollLink').setState(state);
				});

				editor.on('doubleclick', function(evt){
					var command = editor.getCommand('LJPollLink');
					if(command.state == CKEDITOR.TRISTATE_ON){
						command.exec();
						evt.data.dialog = '';
					}
				});

				CKEDITOR.dialog.add('LJPollDialog', function(){
					var isAllFrameLoad = 0, okButtonNode, questionsWindow, setupWindow;

					var onLoadPollPage = function(){
						if(this.removeListener){
							this.removeListener('load', onLoadPollPage);
						}
						if(isAllFrameLoad && okButtonNode){
							currentPoll = new Poll(ljNoteData.LJPollLink.node && unescape(ljNoteData.LJPollLink.node.getAttribute('data')), questionsWindow
								.document, setupWindow.document, questionsWindow.Questions);

							questionsWindow.ready(currentPoll);
							setupWindow.ready(currentPoll);

							okButtonNode.style.display = 'block';
						} else {
							isAllFrameLoad++;
						}
					};

					return {
						title : top.CKLang.Poll_PollWizardTitle,
						width : 420,
						height : 270,
						onShow: function(){
							if(isAllFrameLoad){
								currentPoll = new Poll(ljNoteData.LJPollLink.node && unescape(ljNoteData.LJPollLink.node
									.getAttribute('data')), questionsWindow.document, setupWindow.document, questionsWindow.Questions);

								questionsWindow.ready(currentPoll);
								setupWindow.ready(currentPoll);
							}
						},
						contents : [
							{
								id : 'LJPool_Setup',
								label : 'Setup',
								padding: 0,
								elements :[
									{
										type : 'html',
										html : '<iframe src="/tools/ck_poll_setup.bml" allowTransparency="true" frameborder="0" style="width:100%; height:320px;"></iframe>',
										onShow: function(data){
											if(!okButtonNode){
												(okButtonNode = document.getElementById(data.sender.getButton('LJPool_Ok').domId).parentNode)
													.style.display = 'none';
											}
											var iframe = this.getElement('iframe');
											setupWindow = iframe.$.contentWindow;
											if(setupWindow.ready){
												onLoadPollPage();
											} else {
												iframe.on('load', onLoadPollPage);
											}
										}
									}
								]
							},
							{
								id : 'LJPool_Questions',
								label : 'Questions',
								padding: 0,
								elements:[
									{
										type : 'html',
										html : '<iframe src="/tools/ck_poll_questions.bml" allowTransparency="true" frameborder="0" style="width:100%; height:320px;"></iframe>',
										onShow: function(){
											var iframe = this.getElement('iframe');
											questionsWindow = iframe.$.contentWindow;
											if(questionsWindow.ready){
												onLoadPollPage();
											} else {
												iframe.on('load', onLoadPollPage);
											}
										}
									}
								]
							}
						],
						buttons : [new CKEDITOR.ui.button({
							type : 'button',
							id : 'LJPool_Ok',
							label : editor.lang.common.ok,
							onClick : function(evt){
								evt.data.dialog.hide();
								var pollSource = new Poll(currentPoll, questionsWindow.document, setupWindow.document, questionsWindow
									.Questions).outputHTML();

								if(pollSource.length > 0){
									if(ljNoteData.LJPollLink.node){
										var node = editor.document.createElement('div');
										node.setHtml(pollSource);
										ljNoteData.LJPollLink.node.insertBeforeMe(node);
										ljNoteData.LJPollLink.node.remove();
									} else {
										editor.insertHtml(pollSource);
									}
									ljNoteData.LJPollLink.node = null;
								}
							}
						}), CKEDITOR.dialog.cancelButton]
					};
				});

				editor.addCommand('LJPollLink', new CKEDITOR.dialogCommand('LJPollDialog'));
			} else {
				editor.addCommand('LJPollLink', {
					exec: function(){
						note.show(top.CKLang.Poll_AccountLevelNotice);
					}
				});

				editor.getCommand('LJPollLink').setState(CKEDITOR.TRISTATE_DISABLED);
			}

			editor.ui.addButton('LJPollLink', {
				label: top.CKLang.Poll,
				command: 'LJPollLink'
			});

			//////////  LJ Like Button //////////////
			var buttonsLength = likeButtons.length;
			var dialogContent = '<ul class="likes">';
			likeButtons.defaultButtons = [];

			for(var i = 0; i < buttonsLength; i++){
				var button = likeButtons[i];
				likeButtons[button.id] = likeButtons[button.abbr] = button;
				likeButtons.defaultButtons.push(button.id);
				dialogContent += button.htmlOpt;
			}

			dialogContent += '</ul>' + window.faqLink;

			var countChanges = 0, ljLikeDialog, ljLikeInputs;
			
			function onChangeLike(){
				var command = editor.getCommand('LJLike');
				if(command.state == CKEDITOR.TRISTATE_OFF){
					this.$.checked ? countChanges++ : countChanges--;
					ljLikeDialog.getButton('LJLike_Ok').getElement()[countChanges == 0 ? 'addClass' : 'removeClass']('btn-disabled');
				}
			}

			CKEDITOR.dialog.add('LJLikeDialog', function(){
				return {
					title : top.CKLang.LJLike_name,
					width : 145,
					height : 180,
					resizable: false,
					contents : [
						{
							id: 'LJLike_Options',
							elements: [{
								type: 'html',
								html: dialogContent
							}]
						}
					],
					buttons : [new CKEDITOR.ui.button({
						type : 'button',
						id : 'LJLike_Ok',
						label : editor.lang.common.ok,
						onClick : function(){
							if(ljLikeDialog.getButton('LJLike_Ok').getElement().hasClass('btn-disabled')){
								return false;
							}

							var attr = [],
								likeHtml = '',
								likeNode = ljNoteData.LJLike.node;

							for(var i = 0; i < buttonsLength; i++){
								var button = likeButtons[i];
								var input = document.getElementById('like-' + button.abbr);
								var currentBtn = likeNode && likeNode.getAttribute('buttons');
								if((input && input.checked) || (currentBtn && !button.htmlOpt && (currentBtn.indexOf(button.abbr) + 1 || currentBtn.indexOf(button
									.id) + 1))){
									attr.push(button.id);
									likeHtml += button.html;
								}
							}

							if(attr.length){
								if(likeNode){
									ljNoteData.LJLike.node.setAttribute('buttons', attr.join(','));
									ljNoteData.LJLike.node.setHtml(likeHtml);
								} else {
									editor.insertHtml('<div class="lj-like" lj-cmd="LJLike" buttons="' + attr.join(',') + '">' + likeHtml + '</div>');
								}
							} else if(likeNode){
								ljNoteData.LJLike.node.remove();
							}

							ljLikeDialog.hide();
						}
					}), CKEDITOR.dialog.cancelButton],
					onShow: function(){
						var command = editor.getCommand('LJLike');
						var i = countChanges = 0,
							isOn = command.state == CKEDITOR.TRISTATE_ON,
							buttons = ljNoteData.LJLike.node && ljNoteData.LJLike.node.getAttribute('buttons');

						for(; i < buttonsLength; i++){
							var isChecked = buttons ? !!(buttons.indexOf(likeButtons[i].abbr) + 1 || buttons.indexOf(likeButtons[i]
								.id) + 1) : true;

							var input = document.getElementById('like-' + likeButtons[i].abbr);

							if(input){
								if(isChecked && !isOn){
									countChanges++;
								}

								input.checked = isChecked;
							}
						}

						if(countChanges > 0){
							ljLikeDialog.getButton('LJLike_Ok').getElement().removeClass('btn-disabled');
						}
					},
					onLoad: function(){
						ljLikeDialog = this;
						ljLikeInputs = ljLikeDialog.parts.contents.getElementsByTag('input');
						for(var i = 0; i < buttonsLength; i++){
							var item = ljLikeInputs.getItem(i);
							item && item.on('click', onChangeLike);
						}
					}
				}
			});

			editor.attachStyleStateChange(new CKEDITOR.style({
				element: 'div'
			}), function(){
				var ljLikeNode = this.getSelection().getStartElement();

				while(ljLikeNode){
					if(ljLikeNode.hasClass('lj-like')){
						ljNoteData.LJLike.node = ljLikeNode;
						break;
					}
					ljLikeNode = ljLikeNode.getParent();
				}

				if(!ljLikeNode && !currentNoteNode){
					delete ljNoteData.LJLike.node;
				}

				editor.getCommand('LJLike').setState(ljLikeNode ? CKEDITOR.TRISTATE_ON : CKEDITOR.TRISTATE_OFF);
			});

			editor.on('doubleclick', function(){
				var command = editor.getCommand('LJLike');
				if(command.state == CKEDITOR.TRISTATE_ON){
					command.exec();
				}
			});

			editor.addCommand('LJLike', new CKEDITOR.dialogCommand('LJLikeDialog'));

			editor.ui.addButton('LJLike', {
				label: top.CKLang.LJLike_name,
				command: 'LJLike'
			});
		},
		afterInit : function(editor){
			var flashFilenameRegex = /\.swf(?:$|\?)/i;

			function isFlashEmbed(element){
				var attributes = element.attributes;

				return ( attributes.type == 'application/x-shockwave-flash' || flashFilenameRegex.test(attributes.src || '') );
			}

			function createFakeElement(editor, realElement){
				return editor.createFakeParserElement(realElement, 'lj-embed', 'flash', false);
			}

			var dataProcessor = editor.dataProcessor;

			dataProcessor.dataFilter.addRules({
				elements: {
					'lj-cut': function(element){
						element.attributes['lj-cmd'] = 'LJCut';
					},
					'cke:object' : function(element){
						//////////  LJ Embed Media Button //////////////
						var attributes = element.attributes,
							classId = attributes.classid && String(attributes.classid).toLowerCase();

						if(!classId && !isFlashEmbed(element)){
							for(var i = 0; i < element.children.length; i++){
								if(element.children[i].name == 'cke:embed'){
									return isFlashEmbed(element.children[i]) ? createFakeElement(editor, element) : null;
								}
							}
							return null;
						}

						return createFakeElement(editor, element);
					},
					'cke:embed' : function(element){
						return isFlashEmbed(element) ? createFakeElement(editor, element) : null;
					},
					'lj-like': function(element){
						var attr = [];

						var fakeElement = new CKEDITOR.htmlParser.element('div');
						fakeElement.attributes['class'] = 'lj-like';
						fakeElement.attributes['lj-cmd'] = 'LJLike';

						var currentButtons = element.attributes.buttons && element.attributes.buttons.split(',') || likeButtons
							.defaultButtons;

						var length = currentButtons.length;
						for(var i = 0; i < length; i++){
							var buttonName = currentButtons[i].replace(/^\s*([a-z]{2,})\s*$/i, '$1');
							var button = likeButtons[buttonName];
							if(button){
								var buttonNode = new CKEDITOR.htmlParser.fragment.fromHtml(button.html).children[0];
								fakeElement.add(buttonNode);
								attr.push(buttonName);
							}
						}

						fakeElement.attributes.buttons = attr.join(',');
						fakeElement.attributes.style = element.attributes.style;
						return fakeElement;
					},
					'lj': function(element){
						var ljUserName = element.attributes.user;
						if(!ljUserName || !ljUserName.length){
							return;
						}
						
						var ljUserTitle = element.attributes.title;
						var cacheName = ljUserTitle ? ljUserName + ':' + ljUserTitle : ljUserName;
						
						if(ljUsers.hasOwnProperty(cacheName)){
							var ljTag = (new CKEDITOR.htmlParser.fragment.fromHtml(ljUsers[cacheName])).children[0];

							ljTag.attributes['lj-cmd'] = 'LJUserLink';
							return ljTag;
						} else {
							var onSuccess = function(data){
								ljUsers[cacheName] = data.ljuser;

								if(data.error){
									return alert(data.error + ' "' + username + '"');
								}
								if(!data.success){
									return;
								}

								data.ljuser = data.ljuser.replace("<span class='useralias-value'>*</span>", '');

								var ljTags = editor.document.getElementsByTag('lj');

								for(var i = 0, l = ljTags.count(); i < l; i++){
									var ljTag = ljTags.getItem(i);

									var userName = ljTag.getAttribute('user');
									var userTitle = ljTag.getAttribute('title');
									if(cacheName == userTitle ? userName + ':' + userTitle : userName){
										ljTag.setHtml(ljUsers[cacheName]);
										var newLjTag = ljTag.getFirst();
										newLjTag.setAttribute('lj-cmd', 'LJUserLink');
										ljTag.insertBeforeMe(newLjTag);
										ljTag.remove();
									}
								}
							};

							var onError = function(err){
								alert(err + ' "' + ljUserName + '"');
							};

							var postData = {
								username: ljUserName
							};

							if(ljUserTitle){
								postData.usertitle = ljUserTitle;
							}

							HTTPReq.getJSON({
								data: HTTPReq.formEncoded(postData),
								method: 'POST',
								url: Site.siteroot + '/tools/endpoints/ljuser.bml',
								onError: onError,
								onData: onSuccess
							});
						}
					},
					a: function(element){
						element.attributes['lj-cmd'] = 'LJLink';
					},
					img: function(element){
						element.attributes['lj-cmd'] = 'LJImage';
					}
				}
			}, 5);

			dataProcessor.htmlFilter.addRules({
				elements: {
					div: function(element){
						if(element.attributes['class'] == 'lj-like'){
							var ljLikeNode = new CKEDITOR.htmlParser.element('lj-like');
							ljLikeNode.attributes.buttons = element.attributes.buttons;
							if(element.attributes.style){
								ljLikeNode.attributes.style = element.attributes.style;
							}
							ljLikeNode.isEmpty = true;
							ljLikeNode.isOptionalClose = true;
							return ljLikeNode;
						} else if(!element.children.length){
							return false;
						}
					},
					span: function(element){
						var userName = element.attributes['lj:user'];
						if(userName){
							var ljUserNode = new CKEDITOR.htmlParser.element('lj');
							ljUserNode.attributes.user = userName;
							var userTitle = element.children[1].children[0].children[0].value;

							if(userTitle && userTitle != userName){
								ljUserNode.attributes.title = userTitle;
							}

							ljUserNode.isOptionalClose = ljUserNode.isEmpty = true;
							return ljUserNode;
						}
					}
				},
				attributes: {
					'lj-cmd': function(){
						return false;
					}
				}
			});
		},

		requires : [ 'fakeobjects' ]
	});

})();