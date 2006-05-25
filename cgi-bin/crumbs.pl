#!/usr/bin/perl
#
# Stores all global crumbs and builds the crumbs hash

%LJ::CRUMBS = (
               'acctstatus' => ['Account Status', '/accountstatus.bml', 'manage'],
               'addfriend' => ['Add Friend', '', 'friends'],
               'addtodo' => ['Add To-Do Item', '', 'todo'],
               'advcustomize' => ['Customize Advanced S2 Settings', '/customize/advanced/index.bml', 'manage'],
               'advsearch' => ['Advanced Search', '/directorysearch.bml', 'search'],
               'birthdays' => ['Birthdays', '/birthdays.bml', 'friends'],
               'changeemail' => ['Change Email Address', '/changeemail.bml', 'editprofile'],
               'changepass' => ['Change Password', '/changepassword.bml', 'manage'],
               'comminvites' => ['Community Invitations', '/manage/invites.bml', 'manage'],
               'commmembers' => ['Community Membership', '', 'managecommunity'],
               'commpending' => ['Pending Memberships', '', 'managecommunity'],
               'commsearch' => ['Community Search', '/community/search.bml', 'community'],
               'commsentinvites' => ['Sent Invitations', '/community/sentinvites.bml', 'managecommunity'],
               'commsettings' => ['Community Settings', '/community/settings.bml', 'managecommunity'],
               'community' => ['Community Center', '/community/', 'home'],
               'createcommunity' => ['Create Community', '/community/create.bml', 'managecommunity'],
               'createjournal' => ['Create Journal', '/create.bml', 'home'],
               'createstyle' => ['Create Style', '/styles/create.bml', 'modify'],
               'customize' => ['Customize S2 Settings', '/customize/index.bml', 'manage'],
               'customizelayer' => ['Individual Customizations', '/customize/layer.bml', 'customize'],
               'delcomment' => ['Delete Comment', '/delcomment.bml', 'home'],
               'editcomments' => ['Comment Settings', '/manage/profile/', 'manage'],
               'editentries' => ['Edit Entries', '/editjournal.bml', 'manage'],
               'editentries_do' => ['Edit Entry', '/editjournal_do.bml', 'editentries'],
               'editfriends' => ['Edit Friends', '/friends/edit.bml', 'friends'],
               'editfriendgrps' => ['Edit Friends Groups', '/friends/editgroups.bml', 'friends'],
               'editinfo' => ['Personal Info', '/manage/profile/', 'manage'],
               'editprofile' => ['Edit Profile', '/manage/profile/', 'manage'],
               'edituserpics' => ['Edit Userpics', '/editpics.bml', 'manage'],
               'editsettings' => ['Viewing Options', '/manage/profile/', 'manage'],
               'editstyle' => ['Edit Style', '/styles/edit.bml', 'modify'],
               'emailmanage' => ['Email Management', '/tools/emailmanage.bml', 'manage'],
               'encodings' => ['About Encodings', '/support/encodings.bml', 'support'],
               'export' => ['Export Journal', '/export.bml', 'home'],
               'faq' => ['Frequently Asked Questions', '/support/faq.bml', 'support'],
               'feedstersearch' => ['Search a Journal', '/tools/search.bml', 'home'],
               'friends' => ['Friends Tools', '/friends/index.bml', 'manage'],
               'friendsfilter' => ['Friends Filter', '/friends/filter.bml', 'friends'],
               'home' => ['Home', '/', ''],
               'invitefriend' => ['Invite a Friend', '/friends/invite.bml', 'friends'],
               'joincomm' => ['Join Community', '', 'community'],
               'latestposts' => ['Latest Posts', '/stats/latest.bml', 'stats'],
               'layerbrowse' => ['Public Layer Browser', '/customize/advanced/layerbrowse.bml', 'advcustomize'],
               'leavecomm' => ['Leave Community', '', 'community'],
               'linkslist' => ['Your Links', '/manage/links.bml', 'manage'],
               'login' => ['Login', '/login.bml', 'home'],
               'logout' => ['Logout', '/logout.bml', 'home'],
               'lostinfo' => ['Lost Info', '/lostinfo.bml', 'manage'],
               'manage' => ['Manage Accounts', '/manage/', 'home'],
               'managecommunity' => ['Community Management', '/community/manage.bml', 'manage'],
               'managelogins' => ['Manage Your Login Sessions', '/manage/logins.bml', 'manage'],
               'meme' => ['Meme Tracker', '/meme.bml', 'home'],
               'memories' => ['Memorable Posts', '/tools/memories.bml', 'manage'],
               'mobilepost' => ['Mobile Post Settings', '/manage/emailpost.bml', 'manage'],
               'moderate' => ['Community Moderation', '/community/moderate.bml', 'community'],
               'modify' => ['Journal Settings', '/modify.bml', 'manage'],
               'moodeditor' => ['Custom Mood Theme Editor', '/manage/moodthemes.bml', 'manage'],
               'moodlist' => ['Mood Viewer', '/moodlist.bml', 'manage'],
               'news' => ['News', '/news.bml', 'home'],
               'nudgefriend' => ['Nudge a Friend', '/friends/nudge.bml', 'friends'],
               'popfaq' => ['Popular FAQs', '/support/popfaq.bml', 'faq'],
               'preview' => ['Layout Previews', '/customize/preview.bml', 'customize'],
               'register' => ['Validate Email', '/register.bml', 'home'],
               'schools' => ['Schools Directory', '/schools/index.bml', 'home'],
               'schoolsfind' => ['Find a School', '', 'schools'],
               'schoolsmy' => ['My Schools', '/schools/manage.bml', 'schools'],
               'searchinterests' => ['Search By Interest', '/interests.bml', 'search'],
               'searchregion' => ['Search By Region', '/directory.bml', 'search'],
               'seeoverrides' => ['View User Overrides', '', 'support'],
               'setpgpkey' => ['Public Key', '/manage/pubkey.bml', 'manage'],
               'siteopts' => ['Browse Preferences', '/manage/siteopts.bml', 'manage'],
               'stats' => ['Statistics', '/stats.bml', 'about'],
               'styles' => ['Styles', '/styles/index.bml', 'modify'],
               'support' => ['Support', '/support/index.bml', 'home'],
               'supportact' => ['Request Action', '', 'support'],
               'supportappend' => ['Append to Request', '', 'support'],
               'supporthelp' => ['Request Board', '/support/help.bml', 'support'],
               'supportnotify' => ['Notification Settings', '/support/changenotify.bml', 'support'],
               'supportscores' => ['High Scores', '/support/highscores.bml', 'support'],
               'supportsubmit' => ['Submit Request', '/support/submit.bml', 'support'],
               'textmessage' => ['Send Text Message', '/tools/textmessage.bml', 'home'],
               'themes' => ['Theme Previews', '/customize/themes.bml', 'customize'],
               'todo' => ['Todo List', '/todo', 'home'],
               'transfercomm' => ['Transfer Community', '/community/transfer.bml', 'managecommunity'],
               'translate' => ['Translation Area', '/translate/index.bml', 'home'],
               'translateteams' => ['Translation Teams', '/translate/teams.bml', 'translate'],
               'unsubscribe' => ['Unsubscribe', '/unsubscribe.bml', 'home'],
               'update' => ['Update Journal', '/update.bml', 'home'],
               'utf8convert' => ['UTF-8 Converter', '/utf8convert.bml', 'manage'],
               'yourlayers' => ['Your Layers', '/customize/advanced/layers.bml', 'advcustomize'],
               'yourstyles' => ['Your Styles', '/customize/advanced/styles.bml', 'advcustomize'],
           );

# include the local crumbs info
require "$ENV{'LJHOME'}/cgi-bin/crumbs-local.pl"
    if -e "$ENV{'LJHOME'}/cgi-bin/crumbs-local.pl";

1;
