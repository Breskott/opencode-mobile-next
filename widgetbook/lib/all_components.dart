// Every component in the catalog, in tree order. Add new ones here.
import 'catalog.dart';
import 'chat/chats_list.dart';
import 'chat/conversation.dart';
import 'chat/diff_view.dart';
import 'chat/file_mentions.dart';
import 'chat/task_chip.dart';
import 'chat/work_steps.dart';
import 'guide/guide.dart';
import 'servers/capabilities.dart';
import 'servers/this_phone.dart';
import 'servers/team_phone_setup.dart';
import 'usage/others.dart';
import 'usage/plans.dart';
import 'usage/subscription.dart';

List<CatalogComponent> allComponents() => [
  usagePlansPage(),
  usageSubscriptionPage(),
  usageAlertsPage(),
  usageAddPicker(),
  usageAddFlow(),
  usageReadFromPc(),
  usageWidgetSettings(),
  kitWindowRow(),
  serverCapabilities(),
  guideScreen(),
  chatsHome(),
  allConversations(),
  conversationScreen(),
  kitTaskChip(),
  kitFileMentions(),
  kitDiffView(),
  kitWorkSteps(),
  thisPhoneScreen(),
  teamPhoneSetupScreen(),
];
