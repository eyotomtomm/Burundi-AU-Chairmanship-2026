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
      'agenda': g.agenda,
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
      'generic_error': g.generic_error,
      'yd_documents_after_acceptance': g.yd_documents_after_acceptance,
      'camera_permission_denied': g.camera_permission_denied,
      'explore_terms_title': g.explore_terms_title,
      'explore_terms_subtitle': g.explore_terms_subtitle,
      'explore_terms_before_posting': g.explore_terms_before_posting,
      'explore_terms_complete_profile': g.explore_terms_complete_profile,
      'explore_terms_agree': g.explore_terms_agree,
      'explore_terms_continue': g.explore_terms_continue,
      'explore_terms_english_prevails': g.explore_terms_english_prevails,
      'ok': g.ok,
      'yes': g.yes,
      'no': g.no,
      'delete': g.delete,
      'remove': g.remove,
      'edit': g.edit,
      'send': g.send,
      'submit': g.submit,
      'done': g.done,
      'confirm': g.confirm,
      'share': g.share,
      'copy': g.copy,
      'copied': g.copied,
      'refresh': g.refresh,
      'open': g.open,
      'bookmark': g.bookmark,
      'unknown': g.unknown,
      'not_available': g.not_available,
      'no_magazines_found': g.no_magazines_found,
      'live_chat_start_failed': g.live_chat_start_failed,
      'blocked_external_nav': g.blocked_external_nav,
      'could_not_open_platform': g.could_not_open_platform,
      'open_externally': g.open_externally,
      'no_stream_url': g.no_stream_url,
      'no_scheduled_time': g.no_scheduled_time,
      'reminder_add_failed': g.reminder_add_failed,
      'no_phrases_available': g.no_phrases_available,
      'could_not_open_link': g.could_not_open_link,
      'no_active_polls': g.no_active_polls,
      'recording_unavailable': g.recording_unavailable,
      'pdf_not_available': g.pdf_not_available,
      'try_again': g.try_again,
      'failed_to_load': g.failed_to_load,
      'connection_failed': g.connection_failed,
      'server_error_retry': g.server_error_retry,
      'request_failed': g.request_failed,
      'offline_no_internet': g.offline_no_internet,
      'offline_back_online': g.offline_back_online,
      'offline_reconnecting': g.offline_reconnecting,
      'update_required': g.update_required,
      'update_available': g.update_available,
      'update_now': g.update_now,
      'maybe_later': g.maybe_later,
      'whats_new': g.whats_new,
      'got_it': g.got_it,

      'continueText': g.continueText,
      'facts_and_quotes': g.facts_and_quotes,
      'facts': g.facts,
      'quotes': g.quotes,
      'all_facts': g.all_facts,
      'fact_source': g.fact_source,
      'rs_discussion': g.rs_discussion,
      'rs_discussion_not_found': g.rs_discussion_not_found,
      'rs_no_discussions_yet': g.rs_no_discussions_yet,
      'rs_no_replies_yet': g.rs_no_replies_yet,
      'rs_replies': g.rs_replies,
      'rs_write_reply_hint': g.rs_write_reply_hint,
      'rs_comment_post_failed': g.rs_comment_post_failed,
      'rs_load_more_replies': g.rs_load_more_replies,
      'w_new_post': g.w_new_post,
      'w_title': g.w_title,
      'w_category': g.w_category,
      'w_post': g.w_post,
      'w_photo': g.w_photo,
      'w_video': g.w_video,
      'w_poll': g.w_poll,
      'w_ask_question': g.w_ask_question,
      'w_option': g.w_option,
      'w_add_option': g.w_add_option,
      'w_answering': g.w_answering,
      'w_poll_skipped': g.w_poll_skipped,
      'w_attachment_skipped': g.w_attachment_skipped,
      'w_file_too_large': g.w_file_too_large,
      'w_complete_profile_title': g.w_complete_profile_title,
      'w_complete_profile_body': g.w_complete_profile_body,
      'w_not_now': g.w_not_now,
      'w_repost': g.w_repost,
      'w_repost_sub': g.w_repost_sub,
      'w_repost_removed': g.w_repost_removed,
      'w_quote': g.w_quote,
      'w_quote_sub': g.w_quote_sub,
      'w_add_take_hint': g.w_add_take_hint,
      'w_report': g.w_report,
      'w_report_post': g.w_report_post,
      'w_report_account': g.w_report_account,
      'w_report_this_post': g.w_report_this_post,
      'w_this_account': g.w_this_account,
      'w_what_is_wrong': g.w_what_is_wrong,
      'w_delete_post': g.w_delete_post,
      'w_delete_post_body': g.w_delete_post_body,
      'w_block': g.w_block,
      'w_block_account': g.w_block_account,
      'w_block_body': g.w_block_body,
      'w_blocked_done': g.w_blocked_done,
      'w_unblock': g.w_unblock,
      'w_blocked_accounts': g.w_blocked_accounts,
      'w_edited': g.w_edited,
      'w_leaving_app': g.w_leaving_app,
      'w_link_opens_browser': g.w_link_opens_browser,
      'w_image_load_failed': g.w_image_load_failed,
      'w_clear': g.w_clear,
      'w_congratulations': g.w_congratulations,
      'xt_accountable': g.xt_accountable,
      'xt_we_still_need': g.xt_we_still_need,
      'xt_field_name': g.xt_field_name,
      'xt_field_photo': g.xt_field_photo,
      'xt_field_country': g.xt_field_country,
      'xt_field_dob': g.xt_field_dob,
      'xt_field_phone': g.xt_field_phone,
      'w_appeal_explain': g.w_appeal_explain,
      'w_appeal_hint': g.w_appeal_hint,
      'w_appeal_more_details': g.w_appeal_more_details,
      'w_appeal_reason_required': g.w_appeal_reason_required,
    };
  }

  String translate(String key) {
    return _cache[key] ?? key;
  }

  /// Typed generated class — use for keys with placeholders,
  /// e.g. `l10n.gen.some_key(arg)`.
  AppLocalizationsGenerated get gen => _gen;

  /// Context-free lookup for services (language set by [LanguageProvider]).
  static String languageCode = 'en';
  static AppLocalizationsGenerated get current =>
      lookupAppLocalizationsGenerated(Locale(languageCode));

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
