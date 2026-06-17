import 'package:flutter/material.dart';
import 'app_localizations_generated.dart';

/// Compatibility bridge over the generated [AppLocalizationsGenerated] class.
///
/// Keeps the existing `translate(key)` API and all convenience getters so that
/// **zero call-site changes** are needed across the app.  Internally everything
/// now delegates to the ARB-generated typed class.
class AppLocalizations {
  final Locale locale;
  final AppLocalizationsGenerated _gen;

  AppLocalizations._(this.locale, this._gen);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ---------------------------------------------------------------------------
  // translate(key) — maps old string keys to generated getters
  // ---------------------------------------------------------------------------

  late final Map<String, String> _cache = _buildCache();

  Map<String, String> _buildCache() {
    final g = _gen;
    return {
      'app_name': g.app_name,
      'welcome': g.welcome,
      'continue': g.continueText,
      'skip': g.skip,
      'cancel': g.cancel,
      'save': g.save,
      'close': g.close,
      'search': g.search,
      'loading': g.loading,
      'error': g.error,
      'retry': g.retry,
      'no_data': g.no_data,
      'success': g.success,
      'home': g.home,
      'magazine': g.magazine,
      'locations': g.locations,
      'more': g.more,
      'sign_in': g.sign_in,
      'sign_up': g.sign_up,
      'sign_out': g.sign_out,
      'email': g.email,
      'password': g.password,
      'confirm_password': g.confirm_password,
      'full_name': g.full_name,
      'forgot_password': g.forgot_password,
      'no_account': g.no_account,
      'have_account': g.have_account,
      'or_continue_with': g.or_continue_with,
      'skip_for_now': g.skip_for_now,
      'create_account': g.create_account,
      'welcome_back': g.welcome_back,
      'sign_in_continue': g.sign_in_continue,
      'create_account_text': g.create_account_text,
      'au_chairmanship': g.au_chairmanship,
      'burundi_chairmanship': g.burundi_chairmanship,
      'explore_features': g.explore_features,
      'latest_news': g.latest_news,
      'upcoming_events': g.upcoming_events,
      'quick_access': g.quick_access,
      'priority_agenda': g.priority_agenda,
      'digital_magazine': g.digital_magazine,
      'digital_magazine_desc': g.digital_magazine_desc,
      'embassy_locations': g.embassy_locations,
      'embassy_locations_desc': g.embassy_locations_desc,
      'live_feeds': g.live_feeds,
      'live_feeds_desc': g.live_feeds_desc,
      'resources': g.resources,
      'resources_desc': g.resources_desc,
      'quick_reference': g.quick_reference,
      'quick_reference_desc': g.quick_reference_desc,
      'latest_edition': g.latest_edition,
      'featured_edition': g.featured_edition,
      'past_editions': g.past_editions,
      'featured_articles': g.featured_articles,
      'articles': g.articles,
      'read_more': g.read_more,
      'download': g.download,
      'embassies': g.embassies,
      'embassies_consulates': g.embassies_consulates,
      'events': g.events,
      'get_directions': g.get_directions,
      'call': g.call,
      'view_on_map': g.view_on_map,
      'settings': g.settings,
      'language': g.language,
      'english': g.english,
      'french': g.french,
      'theme': g.theme,
      'dark': g.dark,
      'light': g.light,
      'dark_mode': g.dark_mode,
      'light_mode': g.light_mode,
      'notifications': g.notifications,
      'about': g.about,
      'designed_by': g.designed_by,
      'privacy_policy': g.privacy_policy,
      'share_app': g.share_app,
      'rate_app': g.rate_app,
      'contact_support': g.contact_support,
      'tap_to_sign_in': g.tap_to_sign_in,
      'terms_of_service': g.terms_of_service,
      'version': g.version,
      'contact_us': g.contact_us,
      'get_verified': g.get_verified,
      'get_verified_desc': g.get_verified_desc,
      'republic_of_burundi': g.republic_of_burundi,
      'african_union': g.african_union,
      'chairmanship_2025': g.chairmanship_2025,
      'live': g.live,
      'watch_now': g.watch_now,
      'upcoming': g.upcoming,
      'recorded': g.recorded,
      'translate': g.translate,
      'phrasebook': g.phrasebook,
      'weather': g.weather,
      'calendar': g.calendar,
      'no_events': g.no_events,
      'profile': g.profile,
      'edit_profile': g.edit_profile,
      'my_account': g.my_account,
      'delete_account': g.delete_account,
      'delete_account_desc': g.delete_account_desc,
      'delete_account_confirm': g.delete_account_confirm,
      'export_data': g.export_data,
      'export_data_desc': g.export_data_desc,
      'account_deleted': g.account_deleted,
      'profile_updated': g.profile_updated,
      'update_name': g.update_name,
      'enter_name': g.enter_name,
      'account_settings': g.account_settings,
      'personal_info': g.personal_info,
      'data_privacy': g.data_privacy,
      'danger_zone': g.danger_zone,
      'complete_your_profile': g.complete_your_profile,
      'news': g.news,
      'all_categories': g.all_categories,
      'politics': g.politics,
      'economy': g.economy,
      'culture': g.culture,
      'diplomacy': g.diplomacy,
      'featured': g.featured,
      'views': g.views,
      'comments': g.comments,
      'likes': g.likes,
      'like': g.like,
      'add_comment': g.add_comment,
      'login_to_comment': g.login_to_comment,
      'login_to_like': g.login_to_like,
      'delete_comment': g.delete_comment,
      'delete_comment_confirm': g.delete_comment_confirm,
      'comment_posted': g.comment_posted,
      'comment_deleted': g.comment_deleted,
      'just_now': g.just_now,
      'minutes_ago': g.minutes_ago,
      'hours_ago': g.hours_ago,
      'days_ago': g.days_ago,
      'no_comments_yet': g.no_comments_yet,
      'gallery': g.gallery,
      'watch_video': g.watch_video,
      'change_password': g.change_password,
      'current_password': g.current_password,
      'new_password': g.new_password,
      'login_history': g.login_history,
      'active_sessions': g.active_sessions,
      'password_changed': g.password_changed,
      'password_mismatch': g.password_mismatch,
      'password_too_short': g.password_too_short,
      'field_required': g.field_required,
      'login_gate_title': g.login_gate_title,
      'login_gate_subtitle': g.login_gate_subtitle,
      'login_gate_login': g.login_gate_login,
      'login_gate_signup': g.login_gate_signup,
      'login_gate_locked_badge': g.login_gate_locked_badge,
      'bookmarks': g.bookmarks,
      'saved_content': g.saved_content,
      'no_bookmarks': g.no_bookmarks,
      'discussions': g.discussions,
      'community_forums': g.community_forums,
      'polls': g.polls,
      'vote_share_opinion': g.vote_share_opinion,
      'magazines': g.magazines,
      'videos': g.videos,
      'article': g.article,
      'video': g.video,
      'event': g.event,
      'all': g.all,
      'no_notifications': g.no_notifications,
      'error_loading_notifications': g.error_loading_notifications,
      'notification_preferences': g.notification_preferences,
      'app_guide': g.app_guide,
      'app_guide_subtitle': g.app_guide_subtitle,
      'next': g.next,
      'get_started': g.get_started,
      'onboarding_welcome': g.onboarding_welcome,
      'onboarding_welcome_desc': g.onboarding_welcome_desc,
      'onboarding_news': g.onboarding_news,
      'onboarding_news_desc': g.onboarding_news_desc,
      'onboarding_events': g.onboarding_events,
      'onboarding_events_desc': g.onboarding_events_desc,
      'onboarding_magazine': g.onboarding_magazine,
      'onboarding_magazine_desc': g.onboarding_magazine_desc,
      'onboarding_live': g.onboarding_live,
      'onboarding_live_desc': g.onboarding_live_desc,
      'onboarding_translate': g.onboarding_translate,
      'onboarding_translate_desc': g.onboarding_translate_desc,
      'onboarding_gallery': g.onboarding_gallery,
      'onboarding_gallery_desc': g.onboarding_gallery_desc,
      'error_loading_content': g.error_loading_content,
      'error_loading_subtitle': g.error_loading_subtitle,
      'no_internet_title': g.no_internet_title,
      'no_internet_subtitle': g.no_internet_subtitle,
      'server_error_title': g.server_error_title,
      'server_error_subtitle': g.server_error_subtitle,
      'showing_cached_content': g.showing_cached_content,
      'data_saver': g.data_saver,
      'data_saver_desc': g.data_saver_desc,
    };
  }

  String translate(String key) {
    return _cache[key] ?? key;
  }

  // ---------------------------------------------------------------------------
  // Convenience getters — forward to generated class
  // ---------------------------------------------------------------------------

  String get appName => _gen.app_name;
  String get welcome => _gen.welcome;
  String get continueText => _gen.continueText;
  String get skip => _gen.skip;
  String get cancel => _gen.cancel;
  String get save => _gen.save;
  String get close => _gen.close;
  String get search => _gen.search;
  String get loading => _gen.loading;
  String get error => _gen.error;
  String get retry => _gen.retry;
  String get noData => _gen.no_data;
  String get success => _gen.success;

  // Navigation
  String get home => _gen.home;
  String get magazine => _gen.magazine;
  String get locations => _gen.locations;
  String get more => _gen.more;

  // Auth
  String get signIn => _gen.sign_in;
  String get signUp => _gen.sign_up;
  String get signOut => _gen.sign_out;
  String get email => _gen.email;
  String get password => _gen.password;
  String get confirmPassword => _gen.confirm_password;
  String get fullName => _gen.full_name;
  String get forgotPassword => _gen.forgot_password;
  String get noAccount => _gen.no_account;
  String get haveAccount => _gen.have_account;
  String get orContinueWith => _gen.or_continue_with;
  String get skipForNow => _gen.skip_for_now;
  String get createAccount => _gen.create_account;
  String get welcomeBack => _gen.welcome_back;
  String get signInContinue => _gen.sign_in_continue;
  String get createAccountText => _gen.create_account_text;

  // Features
  String get digitalMagazine => _gen.digital_magazine;
  String get digitalMagazineDesc => _gen.digital_magazine_desc;
  String get embassyLocations => _gen.embassy_locations;
  String get embassyLocationsDesc => _gen.embassy_locations_desc;
  String get liveFeeds => _gen.live_feeds;
  String get liveFeedsDesc => _gen.live_feeds_desc;
  String get resources => _gen.resources;
  String get resourcesDesc => _gen.resources_desc;
  String get quickReference => _gen.quick_reference;
  String get quickReferenceDesc => _gen.quick_reference_desc;

  // Settings
  String get settings => _gen.settings;
  String get language => _gen.language;
  String get english => _gen.english;
  String get french => _gen.french;
  String get theme => _gen.theme;
  String get darkMode => _gen.dark_mode;
  String get lightMode => _gen.light_mode;
  String get notifications => _gen.notifications;
  String get about => _gen.about;
  String get privacyPolicy => _gen.privacy_policy;
  String get termsOfService => _gen.terms_of_service;
  String get version => _gen.version;
  String get contactUs => _gen.contact_us;

  // Splash
  String get republicOfBurundi => _gen.republic_of_burundi;
  String get africanUnion => _gen.african_union;
  String get chairmanship2025 => _gen.chairmanship_2025;

  // Onboarding / App Guide
  String get appGuide => _gen.app_guide;
  String get appGuideSubtitle => _gen.app_guide_subtitle;
  String get next => _gen.next;
  String get getStarted => _gen.get_started;

  // Offline / error / empty states
  String get errorLoadingContent => _gen.error_loading_content;
  String get errorLoadingSubtitle => _gen.error_loading_subtitle;
  String get noInternetTitle => _gen.no_internet_title;
  String get noInternetSubtitle => _gen.no_internet_subtitle;
  String get serverErrorTitle => _gen.server_error_title;
  String get serverErrorSubtitle => _gen.server_error_subtitle;
  String get showingCachedContent => _gen.showing_cached_content;

  // Data saver
  String get dataSaver => _gen.data_saver;
  String get dataSaverDesc => _gen.data_saver_desc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Load the generated class first, then wrap it
    final gen = lookupAppLocalizationsGenerated(locale);
    return AppLocalizations._(locale, gen);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
