import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_generated_en.dart';
import 'app_localizations_generated_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizationsGenerated
/// returned by `AppLocalizationsGenerated.of(context)`.
///
/// Applications need to include `AppLocalizationsGenerated.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations_generated.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizationsGenerated.localizationsDelegates,
///   supportedLocales: AppLocalizationsGenerated.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizationsGenerated.supportedLocales
/// property.
abstract class AppLocalizationsGenerated {
  AppLocalizationsGenerated(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizationsGenerated of(BuildContext context) {
    return Localizations.of<AppLocalizationsGenerated>(
      context,
      AppLocalizationsGenerated,
    )!;
  }

  static const LocalizationsDelegate<AppLocalizationsGenerated> delegate =
      _AppLocalizationsGeneratedDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @app_name.
  ///
  /// In en, this message translates to:
  /// **'Be 4 Africa'**
  String get app_name;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @no_data.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get no_data;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @magazine.
  ///
  /// In en, this message translates to:
  /// **'Magazine'**
  String get magazine;

  /// No description provided for @locations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locations;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get sign_in;

  /// No description provided for @sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get sign_up;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirm_password;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get full_name;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgot_password;

  /// No description provided for @no_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get no_account;

  /// No description provided for @have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get have_account;

  /// No description provided for @or_continue_with.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get or_continue_with;

  /// No description provided for @skip_for_now.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skip_for_now;

  /// No description provided for @create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get create_account;

  /// No description provided for @welcome_back.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcome_back;

  /// No description provided for @sign_in_continue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get sign_in_continue;

  /// No description provided for @create_account_text.
  ///
  /// In en, this message translates to:
  /// **'Create your account to get started'**
  String get create_account_text;

  /// No description provided for @au_chairmanship.
  ///
  /// In en, this message translates to:
  /// **'Be 4 Africa 2025'**
  String get au_chairmanship;

  /// No description provided for @burundi_chairmanship.
  ///
  /// In en, this message translates to:
  /// **'Be 4 Africa'**
  String get burundi_chairmanship;

  /// No description provided for @explore_features.
  ///
  /// In en, this message translates to:
  /// **'Explore Features'**
  String get explore_features;

  /// No description provided for @latest_news.
  ///
  /// In en, this message translates to:
  /// **'Latest News'**
  String get latest_news;

  /// No description provided for @facts_and_quotes.
  ///
  /// In en, this message translates to:
  /// **'Facts & Quotes'**
  String get facts_and_quotes;

  /// No description provided for @facts.
  ///
  /// In en, this message translates to:
  /// **'Facts'**
  String get facts;

  /// No description provided for @quotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get quotes;

  /// No description provided for @all_facts.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all_facts;

  /// No description provided for @fact_source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fact_source;

  /// No description provided for @upcoming_events.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get upcoming_events;

  /// No description provided for @quick_access.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quick_access;

  /// No description provided for @priority_agenda.
  ///
  /// In en, this message translates to:
  /// **'Priority Agenda'**
  String get priority_agenda;

  /// No description provided for @digital_magazine.
  ///
  /// In en, this message translates to:
  /// **'Digital Magazine'**
  String get digital_magazine;

  /// No description provided for @digital_magazine_desc.
  ///
  /// In en, this message translates to:
  /// **'Read the latest publications and news'**
  String get digital_magazine_desc;

  /// No description provided for @embassy_locations.
  ///
  /// In en, this message translates to:
  /// **'Embassy Locations'**
  String get embassy_locations;

  /// No description provided for @embassy_locations_desc.
  ///
  /// In en, this message translates to:
  /// **'Find embassy and event locations'**
  String get embassy_locations_desc;

  /// No description provided for @live_feeds.
  ///
  /// In en, this message translates to:
  /// **'Live Feeds'**
  String get live_feeds;

  /// No description provided for @live_feeds_desc.
  ///
  /// In en, this message translates to:
  /// **'Watch live broadcasts and events'**
  String get live_feeds_desc;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @resources_desc.
  ///
  /// In en, this message translates to:
  /// **'Access documents and resources'**
  String get resources_desc;

  /// No description provided for @quick_reference.
  ///
  /// In en, this message translates to:
  /// **'Quick Reference'**
  String get quick_reference;

  /// No description provided for @quick_reference_desc.
  ///
  /// In en, this message translates to:
  /// **'Important contacts and information'**
  String get quick_reference_desc;

  /// No description provided for @latest_edition.
  ///
  /// In en, this message translates to:
  /// **'Latest Edition'**
  String get latest_edition;

  /// No description provided for @featured_edition.
  ///
  /// In en, this message translates to:
  /// **'Featured Edition'**
  String get featured_edition;

  /// No description provided for @past_editions.
  ///
  /// In en, this message translates to:
  /// **'Past Editions'**
  String get past_editions;

  /// No description provided for @featured_articles.
  ///
  /// In en, this message translates to:
  /// **'Featured News'**
  String get featured_articles;

  /// No description provided for @articles.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get articles;

  /// No description provided for @read_more.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get read_more;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @embassies.
  ///
  /// In en, this message translates to:
  /// **'Embassies'**
  String get embassies;

  /// No description provided for @embassies_consulates.
  ///
  /// In en, this message translates to:
  /// **'Embassies & Consulates'**
  String get embassies_consulates;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @get_directions.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get get_directions;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @view_on_map.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get view_on_map;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @light_mode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get light_mode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @designed_by.
  ///
  /// In en, this message translates to:
  /// **'Designed and developed by'**
  String get designed_by;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @share_app.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get share_app;

  /// No description provided for @rate_app.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rate_app;

  /// No description provided for @contact_support.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contact_support;

  /// No description provided for @tap_to_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign in'**
  String get tap_to_sign_in;

  /// No description provided for @terms_of_service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms_of_service;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @contact_us.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contact_us;

  /// No description provided for @get_verified.
  ///
  /// In en, this message translates to:
  /// **'Get Verified'**
  String get get_verified;

  /// No description provided for @get_verified_desc.
  ///
  /// In en, this message translates to:
  /// **'Request a verified badge for your account'**
  String get get_verified_desc;

  /// No description provided for @republic_of_burundi.
  ///
  /// In en, this message translates to:
  /// **'Republic of Burundi'**
  String get republic_of_burundi;

  /// No description provided for @african_union.
  ///
  /// In en, this message translates to:
  /// **'African Union'**
  String get african_union;

  /// No description provided for @chairmanship_2025.
  ///
  /// In en, this message translates to:
  /// **'Chairmanship 2025'**
  String get chairmanship_2025;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @watch_now.
  ///
  /// In en, this message translates to:
  /// **'Watch Now'**
  String get watch_now;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @recorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recorded;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @phrasebook.
  ///
  /// In en, this message translates to:
  /// **'Phrasebook'**
  String get phrasebook;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @no_events.
  ///
  /// In en, this message translates to:
  /// **'No events available'**
  String get no_events;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// No description provided for @my_account.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get my_account;

  /// No description provided for @delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account;

  /// No description provided for @delete_account_desc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and data'**
  String get delete_account_desc;

  /// No description provided for @delete_account_confirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This action cannot be undone.\n\nAre you sure you want to continue?'**
  String get delete_account_confirm;

  /// No description provided for @export_data.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get export_data;

  /// No description provided for @export_data_desc.
  ///
  /// In en, this message translates to:
  /// **'Download all your account data'**
  String get export_data_desc;

  /// No description provided for @account_deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get account_deleted;

  /// No description provided for @profile_updated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profile_updated;

  /// No description provided for @update_name.
  ///
  /// In en, this message translates to:
  /// **'Update Name'**
  String get update_name;

  /// No description provided for @enter_name.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enter_name;

  /// No description provided for @account_settings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get account_settings;

  /// No description provided for @personal_info.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personal_info;

  /// No description provided for @data_privacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get data_privacy;

  /// No description provided for @danger_zone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get danger_zone;

  /// No description provided for @complete_your_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get complete_your_profile;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @all_categories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all_categories;

  /// No description provided for @politics.
  ///
  /// In en, this message translates to:
  /// **'Politics'**
  String get politics;

  /// No description provided for @economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get economy;

  /// No description provided for @culture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get culture;

  /// No description provided for @diplomacy.
  ///
  /// In en, this message translates to:
  /// **'Diplomacy'**
  String get diplomacy;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'views'**
  String get views;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'likes'**
  String get likes;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @add_comment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get add_comment;

  /// No description provided for @login_to_comment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to comment'**
  String get login_to_comment;

  /// No description provided for @login_to_like.
  ///
  /// In en, this message translates to:
  /// **'Sign in to like'**
  String get login_to_like;

  /// No description provided for @delete_comment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get delete_comment;

  /// No description provided for @delete_comment_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment?'**
  String get delete_comment_confirm;

  /// No description provided for @comment_posted.
  ///
  /// In en, this message translates to:
  /// **'Comment posted'**
  String get comment_posted;

  /// No description provided for @comment_deleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get comment_deleted;

  /// No description provided for @just_now.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get just_now;

  /// No description provided for @minutes_ago.
  ///
  /// In en, this message translates to:
  /// **'min ago'**
  String get minutes_ago;

  /// No description provided for @hours_ago.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hours_ago;

  /// No description provided for @days_ago.
  ///
  /// In en, this message translates to:
  /// **'d ago'**
  String get days_ago;

  /// No description provided for @no_comments_yet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first!'**
  String get no_comments_yet;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @watch_video.
  ///
  /// In en, this message translates to:
  /// **'Watch Video'**
  String get watch_video;

  /// No description provided for @change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get change_password;

  /// No description provided for @current_password.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get current_password;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get new_password;

  /// No description provided for @login_history.
  ///
  /// In en, this message translates to:
  /// **'Login History'**
  String get login_history;

  /// No description provided for @active_sessions.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions'**
  String get active_sessions;

  /// No description provided for @password_changed.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get password_changed;

  /// No description provided for @password_mismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get password_mismatch;

  /// No description provided for @password_too_short.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get password_too_short;

  /// No description provided for @field_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get field_required;

  /// No description provided for @login_gate_title.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get login_gate_title;

  /// No description provided for @login_gate_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the full experience — news, magazines, videos and more.'**
  String get login_gate_subtitle;

  /// No description provided for @login_gate_login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login_gate_login;

  /// No description provided for @login_gate_signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get login_gate_signup;

  /// No description provided for @login_gate_locked_badge.
  ///
  /// In en, this message translates to:
  /// **'Members only'**
  String get login_gate_locked_badge;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @saved_content.
  ///
  /// In en, this message translates to:
  /// **'Saved Content'**
  String get saved_content;

  /// No description provided for @no_bookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get no_bookmarks;

  /// No description provided for @discussions.
  ///
  /// In en, this message translates to:
  /// **'Discussions'**
  String get discussions;

  /// No description provided for @community_forums.
  ///
  /// In en, this message translates to:
  /// **'Community Forums'**
  String get community_forums;

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @vote_share_opinion.
  ///
  /// In en, this message translates to:
  /// **'Vote & Share Your Opinion'**
  String get vote_share_opinion;

  /// No description provided for @magazines.
  ///
  /// In en, this message translates to:
  /// **'Magazines'**
  String get magazines;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @article.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get article;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get no_notifications;

  /// No description provided for @error_loading_notifications.
  ///
  /// In en, this message translates to:
  /// **'Error loading notifications'**
  String get error_loading_notifications;

  /// No description provided for @notification_preferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notification_preferences;

  /// No description provided for @app_guide.
  ///
  /// In en, this message translates to:
  /// **'App Guide'**
  String get app_guide;

  /// No description provided for @app_guide_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn how to use the app'**
  String get app_guide_subtitle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @get_started.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get get_started;

  /// No description provided for @onboarding_welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to B4Africa'**
  String get onboarding_welcome;

  /// No description provided for @onboarding_welcome_desc.
  ///
  /// In en, this message translates to:
  /// **'Your companion for the African Union Chairmanship 2026. Let\'s show you around!'**
  String get onboarding_welcome_desc;

  /// No description provided for @onboarding_news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get onboarding_news;

  /// No description provided for @onboarding_news_desc.
  ///
  /// In en, this message translates to:
  /// **'Stay updated with the latest articles and announcements'**
  String get onboarding_news_desc;

  /// No description provided for @onboarding_events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get onboarding_events;

  /// No description provided for @onboarding_events_desc.
  ///
  /// In en, this message translates to:
  /// **'Browse upcoming events, register, and get tickets'**
  String get onboarding_events_desc;

  /// No description provided for @onboarding_magazine.
  ///
  /// In en, this message translates to:
  /// **'Digital Magazine'**
  String get onboarding_magazine;

  /// No description provided for @onboarding_magazine_desc.
  ///
  /// In en, this message translates to:
  /// **'Read the digital magazine and featured articles'**
  String get onboarding_magazine_desc;

  /// No description provided for @onboarding_live.
  ///
  /// In en, this message translates to:
  /// **'Live Feeds'**
  String get onboarding_live;

  /// No description provided for @onboarding_live_desc.
  ///
  /// In en, this message translates to:
  /// **'Watch live streams and video content'**
  String get onboarding_live_desc;

  /// No description provided for @onboarding_translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get onboarding_translate;

  /// No description provided for @onboarding_translate_desc.
  ///
  /// In en, this message translates to:
  /// **'Translate content between languages instantly'**
  String get onboarding_translate_desc;

  /// No description provided for @onboarding_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get onboarding_gallery;

  /// No description provided for @onboarding_gallery_desc.
  ///
  /// In en, this message translates to:
  /// **'Explore photo albums from events and summits'**
  String get onboarding_gallery_desc;

  /// No description provided for @error_loading_content.
  ///
  /// In en, this message translates to:
  /// **'Unable to load content'**
  String get error_loading_content;

  /// No description provided for @error_loading_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get error_loading_subtitle;

  /// No description provided for @no_internet_title.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get no_internet_title;

  /// No description provided for @no_internet_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and try again.'**
  String get no_internet_subtitle;

  /// No description provided for @server_error_title.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get server_error_title;

  /// No description provided for @server_error_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Please try again later.'**
  String get server_error_subtitle;

  /// No description provided for @showing_cached_content.
  ///
  /// In en, this message translates to:
  /// **'Showing saved content'**
  String get showing_cached_content;

  /// No description provided for @data_saver.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get data_saver;

  /// No description provided for @data_saver_desc.
  ///
  /// In en, this message translates to:
  /// **'Reduce image quality and polling frequency to save data'**
  String get data_saver_desc;
}

class _AppLocalizationsGeneratedDelegate
    extends LocalizationsDelegate<AppLocalizationsGenerated> {
  const _AppLocalizationsGeneratedDelegate();

  @override
  Future<AppLocalizationsGenerated> load(Locale locale) {
    return SynchronousFuture<AppLocalizationsGenerated>(
      lookupAppLocalizationsGenerated(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsGeneratedDelegate old) => false;
}

AppLocalizationsGenerated lookupAppLocalizationsGenerated(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsGeneratedEn();
    case 'fr':
      return AppLocalizationsGeneratedFr();
  }

  throw FlutterError(
    'AppLocalizationsGenerated.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
