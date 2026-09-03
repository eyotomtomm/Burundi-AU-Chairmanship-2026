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

  /// No description provided for @agenda.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get agenda;

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

  /// No description provided for @generic_error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get generic_error;

  /// No description provided for @yd_documents_after_acceptance.
  ///
  /// In en, this message translates to:
  /// **'supporting documents are requested after your application is accepted.'**
  String get yd_documents_after_acceptance;

  /// No description provided for @camera_permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is required to scan codes. Enable it for this app in your device Settings.'**
  String get camera_permission_denied;

  /// No description provided for @explore_terms_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Explore'**
  String get explore_terms_title;

  /// No description provided for @explore_terms_subtitle.
  ///
  /// In en, this message translates to:
  /// **'A public space for youth policy debate. Read this once before you take part.'**
  String get explore_terms_subtitle;

  /// No description provided for @explore_terms_before_posting.
  ///
  /// In en, this message translates to:
  /// **'Before you can post'**
  String get explore_terms_before_posting;

  /// No description provided for @explore_terms_complete_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete my profile'**
  String get explore_terms_complete_profile;

  /// No description provided for @explore_terms_agree.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Explore community terms.'**
  String get explore_terms_agree;

  /// No description provided for @explore_terms_continue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get explore_terms_continue;

  /// No description provided for @explore_terms_english_prevails.
  ///
  /// In en, this message translates to:
  /// **'The English version of these terms is the reference text.'**
  String get explore_terms_english_prevails;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @not_available.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get not_available;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get try_again;

  /// No description provided for @failed_to_load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failed_to_load;

  /// No description provided for @connection_failed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check your network.'**
  String get connection_failed;

  /// No description provided for @server_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get server_error_retry;

  /// No description provided for @request_failed.
  ///
  /// In en, this message translates to:
  /// **'Request failed'**
  String get request_failed;

  /// No description provided for @offline_no_internet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offline_no_internet;

  /// No description provided for @offline_back_online.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get offline_back_online;

  /// No description provided for @offline_reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get offline_reconnecting;

  /// No description provided for @update_required.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get update_required;

  /// No description provided for @update_available.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get update_available;

  /// No description provided for @update_now.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get update_now;

  /// No description provided for @maybe_later.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybe_later;

  /// No description provided for @whats_new.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whats_new;

  /// No description provided for @got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get got_it;

  /// No description provided for @no_magazines_found.
  ///
  /// In en, this message translates to:
  /// **'No magazines found'**
  String get no_magazines_found;

  /// No description provided for @live_chat_start_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not start live chat. Please try again.'**
  String get live_chat_start_failed;

  /// No description provided for @blocked_external_nav.
  ///
  /// In en, this message translates to:
  /// **'Blocked navigation to an external site'**
  String get blocked_external_nav;

  /// No description provided for @could_not_open_platform.
  ///
  /// In en, this message translates to:
  /// **'Could not open this platform'**
  String get could_not_open_platform;

  /// No description provided for @open_externally.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get open_externally;

  /// No description provided for @no_stream_url.
  ///
  /// In en, this message translates to:
  /// **'No stream link is available for this feed'**
  String get no_stream_url;

  /// No description provided for @no_scheduled_time.
  ///
  /// In en, this message translates to:
  /// **'No scheduled time is available for this event'**
  String get no_scheduled_time;

  /// No description provided for @reminder_add_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the reminder. Please try again.'**
  String get reminder_add_failed;

  /// No description provided for @no_phrases_available.
  ///
  /// In en, this message translates to:
  /// **'No phrases available.'**
  String get no_phrases_available;

  /// No description provided for @could_not_open_link.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get could_not_open_link;

  /// No description provided for @no_active_polls.
  ///
  /// In en, this message translates to:
  /// **'No active polls'**
  String get no_active_polls;

  /// No description provided for @recording_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This session recording is not available'**
  String get recording_unavailable;

  /// No description provided for @pdf_not_available.
  ///
  /// In en, this message translates to:
  /// **'PDF not available yet.'**
  String get pdf_not_available;

  /// No description provided for @rs_discussion.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get rs_discussion;

  /// No description provided for @rs_discussion_not_found.
  ///
  /// In en, this message translates to:
  /// **'Discussion not found'**
  String get rs_discussion_not_found;

  /// No description provided for @rs_no_discussions_yet.
  ///
  /// In en, this message translates to:
  /// **'No discussions yet'**
  String get rs_no_discussions_yet;

  /// No description provided for @rs_no_replies_yet.
  ///
  /// In en, this message translates to:
  /// **'No replies yet'**
  String get rs_no_replies_yet;

  /// No description provided for @rs_replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get rs_replies;

  /// No description provided for @rs_write_reply_hint.
  ///
  /// In en, this message translates to:
  /// **'Write a reply…'**
  String get rs_write_reply_hint;

  /// No description provided for @rs_comment_post_failed.
  ///
  /// In en, this message translates to:
  /// **'Your reply could not be posted.'**
  String get rs_comment_post_failed;

  /// No description provided for @rs_load_more_replies.
  ///
  /// In en, this message translates to:
  /// **'Load more replies'**
  String get rs_load_more_replies;

  /// No description provided for @w_new_post.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get w_new_post;

  /// No description provided for @w_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get w_title;

  /// No description provided for @w_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get w_category;

  /// No description provided for @w_post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get w_post;

  /// No description provided for @w_photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get w_photo;

  /// No description provided for @w_video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get w_video;

  /// No description provided for @w_poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get w_poll;

  /// No description provided for @w_ask_question.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get w_ask_question;

  /// No description provided for @w_option.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get w_option;

  /// No description provided for @w_add_option.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get w_add_option;

  /// No description provided for @w_answering.
  ///
  /// In en, this message translates to:
  /// **'Answering'**
  String get w_answering;

  /// No description provided for @w_poll_skipped.
  ///
  /// In en, this message translates to:
  /// **'Poll skipped'**
  String get w_poll_skipped;

  /// No description provided for @w_attachment_skipped.
  ///
  /// In en, this message translates to:
  /// **'Some attachments did not upload'**
  String get w_attachment_skipped;

  /// No description provided for @w_file_too_large.
  ///
  /// In en, this message translates to:
  /// **'That file is too large'**
  String get w_file_too_large;

  /// No description provided for @w_complete_profile_title.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get w_complete_profile_title;

  /// No description provided for @w_complete_profile_body.
  ///
  /// In en, this message translates to:
  /// **'Add the rest of your details before posting.'**
  String get w_complete_profile_body;

  /// No description provided for @w_not_now.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get w_not_now;

  /// No description provided for @w_repost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get w_repost;

  /// No description provided for @w_repost_sub.
  ///
  /// In en, this message translates to:
  /// **'Share this with your followers'**
  String get w_repost_sub;

  /// No description provided for @w_repost_removed.
  ///
  /// In en, this message translates to:
  /// **'Repost removed'**
  String get w_repost_removed;

  /// No description provided for @w_quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get w_quote;

  /// No description provided for @w_quote_sub.
  ///
  /// In en, this message translates to:
  /// **'Add your own take'**
  String get w_quote_sub;

  /// No description provided for @w_add_take_hint.
  ///
  /// In en, this message translates to:
  /// **'Add your take…'**
  String get w_add_take_hint;

  /// No description provided for @w_report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get w_report;

  /// No description provided for @w_report_post.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get w_report_post;

  /// No description provided for @w_report_account.
  ///
  /// In en, this message translates to:
  /// **'Report account'**
  String get w_report_account;

  /// No description provided for @w_report_this_post.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get w_report_this_post;

  /// No description provided for @w_this_account.
  ///
  /// In en, this message translates to:
  /// **'this account'**
  String get w_this_account;

  /// No description provided for @w_what_is_wrong.
  ///
  /// In en, this message translates to:
  /// **'What is wrong with it?'**
  String get w_what_is_wrong;

  /// No description provided for @w_delete_post.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get w_delete_post;

  /// No description provided for @w_delete_post_body.
  ///
  /// In en, this message translates to:
  /// **'This removes it for everyone. It cannot be undone.'**
  String get w_delete_post_body;

  /// No description provided for @w_block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get w_block;

  /// No description provided for @w_block_account.
  ///
  /// In en, this message translates to:
  /// **'Block account'**
  String get w_block_account;

  /// No description provided for @w_block_body.
  ///
  /// In en, this message translates to:
  /// **'You will not see their posts or replies, and they will not see yours.'**
  String get w_block_body;

  /// No description provided for @w_blocked_done.
  ///
  /// In en, this message translates to:
  /// **'Account blocked'**
  String get w_blocked_done;

  /// No description provided for @w_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get w_unblock;

  /// No description provided for @w_blocked_accounts.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get w_blocked_accounts;

  /// No description provided for @w_edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get w_edited;

  /// No description provided for @w_leaving_app.
  ///
  /// In en, this message translates to:
  /// **'Leaving the app'**
  String get w_leaving_app;

  /// No description provided for @w_link_opens_browser.
  ///
  /// In en, this message translates to:
  /// **'This link opens in your browser.'**
  String get w_link_opens_browser;

  /// No description provided for @w_image_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Image could not be loaded'**
  String get w_image_load_failed;

  /// No description provided for @w_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get w_clear;

  /// No description provided for @w_congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations'**
  String get w_congratulations;

  /// No description provided for @xt_accountable.
  ///
  /// In en, this message translates to:
  /// **'Posts here carry your real name and photo. You are accountable for what you write.'**
  String get xt_accountable;

  /// No description provided for @xt_we_still_need.
  ///
  /// In en, this message translates to:
  /// **'We still need'**
  String get xt_we_still_need;

  /// No description provided for @xt_field_name.
  ///
  /// In en, this message translates to:
  /// **'your full name'**
  String get xt_field_name;

  /// No description provided for @xt_field_photo.
  ///
  /// In en, this message translates to:
  /// **'a profile photo'**
  String get xt_field_photo;

  /// No description provided for @xt_field_country.
  ///
  /// In en, this message translates to:
  /// **'your country'**
  String get xt_field_country;

  /// No description provided for @xt_field_dob.
  ///
  /// In en, this message translates to:
  /// **'your date of birth'**
  String get xt_field_dob;

  /// No description provided for @xt_field_phone.
  ///
  /// In en, this message translates to:
  /// **'your phone number'**
  String get xt_field_phone;

  /// No description provided for @w_appeal_explain.
  ///
  /// In en, this message translates to:
  /// **'Tell us why you think this was a mistake.'**
  String get w_appeal_explain;

  /// No description provided for @w_appeal_hint.
  ///
  /// In en, this message translates to:
  /// **'Your explanation…'**
  String get w_appeal_hint;

  /// No description provided for @w_appeal_more_details.
  ///
  /// In en, this message translates to:
  /// **'Please add a little more detail.'**
  String get w_appeal_more_details;

  /// No description provided for @w_appeal_reason_required.
  ///
  /// In en, this message translates to:
  /// **'A reason is required.'**
  String get w_appeal_reason_required;

  /// No description provided for @art_listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get art_listen;

  /// No description provided for @art_text_copied_tts.
  ///
  /// In en, this message translates to:
  /// **'Text copied — use your device\'s text-to-speech feature to listen'**
  String get art_text_copied_tts;

  /// No description provided for @auth_account_exists.
  ///
  /// In en, this message translates to:
  /// **'Account Exists'**
  String get auth_account_exists;

  /// No description provided for @auth_account_exists_body_1.
  ///
  /// In en, this message translates to:
  /// **'An account with'**
  String get auth_account_exists_body_1;

  /// No description provided for @auth_account_exists_body_2.
  ///
  /// In en, this message translates to:
  /// **'is already registered. Please sign in instead.'**
  String get auth_account_exists_body_2;

  /// No description provided for @auth_back_to_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get auth_back_to_sign_in;

  /// No description provided for @auth_check_inbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get auth_check_inbox;

  /// No description provided for @auth_complete_profile_body.
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your experience by completing your profile information.'**
  String get auth_complete_profile_body;

  /// No description provided for @auth_complete_your_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get auth_complete_your_profile;

  /// No description provided for @auth_confirm_password_required.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get auth_confirm_password_required;

  /// No description provided for @auth_continuing_as_guest.
  ///
  /// In en, this message translates to:
  /// **'Continuing as guest'**
  String get auth_continuing_as_guest;

  /// No description provided for @auth_didnt_get_it.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it?'**
  String get auth_didnt_get_it;

  /// No description provided for @auth_email_verification_footnote.
  ///
  /// In en, this message translates to:
  /// **'Email verification is required to access the app. Check your inbox and spam folder.'**
  String get auth_email_verification_footnote;

  /// No description provided for @auth_enter_6_digit_code.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code'**
  String get auth_enter_6_digit_code;

  /// No description provided for @auth_enter_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get auth_enter_email;

  /// No description provided for @auth_go_to_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Go to Sign In'**
  String get auth_go_to_sign_in;

  /// No description provided for @auth_invalid_code.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Try again.'**
  String get auth_invalid_code;

  /// No description provided for @auth_only_take_minute.
  ///
  /// In en, this message translates to:
  /// **'This will only take a minute'**
  String get auth_only_take_minute;

  /// No description provided for @auth_otp_send_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code. Try again.'**
  String get auth_otp_send_failed;

  /// No description provided for @auth_password_required.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get auth_password_required;

  /// No description provided for @auth_passwords_dont_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get auth_passwords_dont_match;

  /// No description provided for @auth_resend_code.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get auth_resend_code;

  /// No description provided for @auth_resend_in.
  ///
  /// In en, this message translates to:
  /// **'Resend in'**
  String get auth_resend_in;

  /// No description provided for @auth_reset_link_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset link. Please try again.'**
  String get auth_reset_link_failed;

  /// No description provided for @auth_reset_link_sent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to'**
  String get auth_reset_link_sent;

  /// No description provided for @auth_reset_password.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get auth_reset_password;

  /// No description provided for @auth_reset_password_body.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get auth_reset_password_body;

  /// No description provided for @auth_send_reset_link.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get auth_send_reset_link;

  /// No description provided for @auth_sending_code.
  ///
  /// In en, this message translates to:
  /// **'Sending verification code…'**
  String get auth_sending_code;

  /// No description provided for @auth_sign_in_to_continue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get auth_sign_in_to_continue;

  /// No description provided for @auth_sign_in_with.
  ///
  /// In en, this message translates to:
  /// **'Sign in with'**
  String get auth_sign_in_with;

  /// No description provided for @auth_use_different_email.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get auth_use_different_email;

  /// No description provided for @auth_verification_failed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Try again.'**
  String get auth_verification_failed;

  /// No description provided for @auth_verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get auth_verify;

  /// No description provided for @auth_verify_email.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get auth_verify_email;

  /// No description provided for @bm_could_not_open_article.
  ///
  /// In en, this message translates to:
  /// **'Could not open this article'**
  String get bm_could_not_open_article;

  /// No description provided for @bm_could_not_remove.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this bookmark'**
  String get bm_could_not_remove;

  /// No description provided for @bm_type_not_supported.
  ///
  /// In en, this message translates to:
  /// **'This bookmark type cannot be opened yet'**
  String get bm_type_not_supported;

  /// No description provided for @bm_untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get bm_untitled;

  /// No description provided for @la_account_unlinked.
  ///
  /// In en, this message translates to:
  /// **'account unlinked'**
  String get la_account_unlinked;

  /// No description provided for @la_already_linked.
  ///
  /// In en, this message translates to:
  /// **'Already linked'**
  String get la_already_linked;

  /// No description provided for @la_apple_linked.
  ///
  /// In en, this message translates to:
  /// **'Apple account linked successfully'**
  String get la_apple_linked;

  /// No description provided for @la_cannot_unlink_only.
  ///
  /// In en, this message translates to:
  /// **'Cannot unlink your only sign-in method. Link another provider first.'**
  String get la_cannot_unlink_only;

  /// No description provided for @la_cannot_unlink_only_short.
  ///
  /// In en, this message translates to:
  /// **'Cannot unlink your only sign-in method'**
  String get la_cannot_unlink_only_short;

  /// No description provided for @la_email_linked.
  ///
  /// In en, this message translates to:
  /// **'Email/password linked successfully'**
  String get la_email_linked;

  /// No description provided for @la_email_password_desc.
  ///
  /// In en, this message translates to:
  /// **'Set an email and password to use as an additional sign-in method.'**
  String get la_email_password_desc;

  /// No description provided for @la_email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get la_email_required;

  /// No description provided for @la_enter_valid_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get la_enter_valid_email;

  /// No description provided for @la_failed_link_apple.
  ///
  /// In en, this message translates to:
  /// **'Failed to link Apple account:'**
  String get la_failed_link_apple;

  /// No description provided for @la_failed_link_email.
  ///
  /// In en, this message translates to:
  /// **'Failed to link email:'**
  String get la_failed_link_email;

  /// No description provided for @la_failed_link_google.
  ///
  /// In en, this message translates to:
  /// **'Failed to link Google account:'**
  String get la_failed_link_google;

  /// No description provided for @la_failed_load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load linked accounts'**
  String get la_failed_load;

  /// No description provided for @la_failed_unlink.
  ///
  /// In en, this message translates to:
  /// **'Failed to unlink:'**
  String get la_failed_unlink;

  /// No description provided for @la_google_linked.
  ///
  /// In en, this message translates to:
  /// **'Google account linked successfully'**
  String get la_google_linked;

  /// No description provided for @la_link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get la_link;

  /// No description provided for @la_link_apple.
  ///
  /// In en, this message translates to:
  /// **'Link Apple Account'**
  String get la_link_apple;

  /// No description provided for @la_link_email_password.
  ///
  /// In en, this message translates to:
  /// **'Link Email/Password'**
  String get la_link_email_password;

  /// No description provided for @la_link_google.
  ///
  /// In en, this message translates to:
  /// **'Link Google Account'**
  String get la_link_google;

  /// No description provided for @la_link_new_provider.
  ///
  /// In en, this message translates to:
  /// **'LINK NEW PROVIDER'**
  String get la_link_new_provider;

  /// No description provided for @la_linked_on.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get la_linked_on;

  /// No description provided for @la_manage_desc.
  ///
  /// In en, this message translates to:
  /// **'Link multiple providers to sign in with any of them. You must keep at least one.'**
  String get la_manage_desc;

  /// No description provided for @la_manage_title.
  ///
  /// In en, this message translates to:
  /// **'Manage sign-in methods'**
  String get la_manage_title;

  /// No description provided for @la_password_min6.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get la_password_min6;

  /// No description provided for @la_primary.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get la_primary;

  /// No description provided for @la_title.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get la_title;

  /// No description provided for @la_unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get la_unlink;

  /// No description provided for @la_unlink_warning_prefix.
  ///
  /// In en, this message translates to:
  /// **'You will no longer be able to sign in with your'**
  String get la_unlink_warning_prefix;

  /// No description provided for @la_unlink_warning_suffix.
  ///
  /// In en, this message translates to:
  /// **'account. Make sure you have another sign-in method available.'**
  String get la_unlink_warning_suffix;

  /// No description provided for @more_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get more_account;

  /// No description provided for @more_community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get more_community;

  /// No description provided for @more_deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get more_deactivate;

  /// No description provided for @more_deactivate_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to deactivate'**
  String get more_deactivate_failed;

  /// No description provided for @more_deactivated_toast.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated. Log in anytime to come back!'**
  String get more_deactivated_toast;

  /// No description provided for @more_delete_account_q.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get more_delete_account_q;

  /// No description provided for @more_delete_body.
  ///
  /// In en, this message translates to:
  /// **'Your account will be scheduled for permanent deletion. You have 30 days to change your mind by logging back in.'**
  String get more_delete_body;

  /// No description provided for @more_delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get more_delete_failed;

  /// No description provided for @more_delete_forever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get more_delete_forever;

  /// No description provided for @more_delete_forever_sub.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all data after 30 days.'**
  String get more_delete_forever_sub;

  /// No description provided for @more_delete_scheduled_toast.
  ///
  /// In en, this message translates to:
  /// **'Account scheduled for deletion. You have 30 days to cancel by logging in.'**
  String get more_delete_scheduled_toast;

  /// No description provided for @more_email_address.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get more_email_address;

  /// No description provided for @more_email_required.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get more_email_required;

  /// No description provided for @more_guest_user.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get more_guest_user;

  /// No description provided for @more_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get more_legal;

  /// No description provided for @more_live_agent.
  ///
  /// In en, this message translates to:
  /// **'Live Agent'**
  String get more_live_agent;

  /// No description provided for @more_live_chat_body.
  ///
  /// In en, this message translates to:
  /// **'Started a live chat session.'**
  String get more_live_chat_body;

  /// No description provided for @more_live_chat_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start live chat:'**
  String get more_live_chat_failed;

  /// No description provided for @more_live_chat_subject.
  ///
  /// In en, this message translates to:
  /// **'Live Chat Support'**
  String get more_live_chat_subject;

  /// No description provided for @more_manage_account.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get more_manage_account;

  /// No description provided for @more_manage_account_sub.
  ///
  /// In en, this message translates to:
  /// **'Deactivate or delete your account'**
  String get more_manage_account_sub;

  /// No description provided for @more_manage_your_account.
  ///
  /// In en, this message translates to:
  /// **'Manage Your Account'**
  String get more_manage_your_account;

  /// No description provided for @more_name_required.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get more_name_required;

  /// No description provided for @more_newsletter.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to receive our monthly digest'**
  String get more_newsletter;

  /// No description provided for @more_newsletter_desc.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to receive our monthly newsletter with the latest updates and news.'**
  String get more_newsletter_desc;

  /// No description provided for @more_phone_optional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (optional)'**
  String get more_phone_optional;

  /// No description provided for @more_preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get more_preferences;

  /// No description provided for @more_rating_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Rating will be available once the app is on the App Store'**
  String get more_rating_unavailable;

  /// No description provided for @more_reach_us.
  ///
  /// In en, this message translates to:
  /// **'How would you like to reach us?'**
  String get more_reach_us;

  /// No description provided for @more_sign_in_to_contact.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to contact support'**
  String get more_sign_in_to_contact;

  /// No description provided for @more_sign_out_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get more_sign_out_confirm;

  /// No description provided for @more_spread_word.
  ///
  /// In en, this message translates to:
  /// **'Spread the word'**
  String get more_spread_word;

  /// No description provided for @more_subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get more_subscribe;

  /// No description provided for @more_subscribe_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to subscribe:'**
  String get more_subscribe_failed;

  /// No description provided for @more_subscribed_toast.
  ///
  /// In en, this message translates to:
  /// **'Subscribed to Monthly Newsletter!'**
  String get more_subscribed_toast;

  /// No description provided for @more_support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get more_support;

  /// No description provided for @more_support_sub.
  ///
  /// In en, this message translates to:
  /// **'Get help and support'**
  String get more_support_sub;

  /// No description provided for @more_support_ticket.
  ///
  /// In en, this message translates to:
  /// **'Support Ticket'**
  String get more_support_ticket;

  /// No description provided for @more_support_ticket_sub.
  ///
  /// In en, this message translates to:
  /// **'Create a ticket, we respond within 24 hours'**
  String get more_support_ticket_sub;

  /// No description provided for @more_take_break.
  ///
  /// In en, this message translates to:
  /// **'Take a Break'**
  String get more_take_break;

  /// No description provided for @more_take_break_body.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deactivated and hidden from others. You can reactivate it anytime by simply logging back in.'**
  String get more_take_break_body;

  /// No description provided for @more_take_break_q.
  ///
  /// In en, this message translates to:
  /// **'Take a break?'**
  String get more_take_break_q;

  /// No description provided for @more_take_break_sub.
  ///
  /// In en, this message translates to:
  /// **'Deactivate temporarily. Log back in anytime to reactivate.'**
  String get more_take_break_sub;

  /// No description provided for @more_thanks_support.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support!'**
  String get more_thanks_support;

  /// No description provided for @more_unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get more_unsubscribe;

  /// No description provided for @more_unsubscribe_body.
  ///
  /// In en, this message translates to:
  /// **'You will no longer receive our monthly newsletter.'**
  String get more_unsubscribe_body;

  /// No description provided for @more_unsubscribe_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unsubscribe:'**
  String get more_unsubscribe_failed;

  /// No description provided for @more_unsubscribe_q.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from newsletter?'**
  String get more_unsubscribe_q;

  /// No description provided for @more_unsubscribed.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed from newsletter'**
  String get more_unsubscribed;

  /// No description provided for @more_user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get more_user;

  /// No description provided for @more_valid_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get more_valid_email;

  /// No description provided for @more_verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get more_verification;

  /// No description provided for @mt_copy_email.
  ///
  /// In en, this message translates to:
  /// **'Copy email address'**
  String get mt_copy_email;

  /// No description provided for @mt_desc.
  ///
  /// In en, this message translates to:
  /// **'We are performing scheduled maintenance. Please try again shortly.'**
  String get mt_desc;

  /// No description provided for @mt_email_copied.
  ///
  /// In en, this message translates to:
  /// **'Email copied:'**
  String get mt_email_copied;

  /// No description provided for @mt_mail_body.
  ///
  /// In en, this message translates to:
  /// **'Hello,\n\nI need assistance while the app is under maintenance.\n\n'**
  String get mt_mail_body;

  /// No description provided for @mt_mail_subject.
  ///
  /// In en, this message translates to:
  /// **'Support Request - Maintenance'**
  String get mt_mail_subject;

  /// No description provided for @mt_server_unreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Please check your connection.'**
  String get mt_server_unreachable;

  /// No description provided for @mt_still_maintenance.
  ///
  /// In en, this message translates to:
  /// **'Still under maintenance. Please try again later.'**
  String get mt_still_maintenance;

  /// No description provided for @mt_title.
  ///
  /// In en, this message translates to:
  /// **'Under Maintenance'**
  String get mt_title;

  /// No description provided for @pc_complete_profile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get pc_complete_profile;

  /// No description provided for @pc_do_later.
  ///
  /// In en, this message translates to:
  /// **'I\'ll do this later'**
  String get pc_do_later;

  /// No description provided for @pc_dob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get pc_dob;

  /// No description provided for @pc_dob_required.
  ///
  /// In en, this message translates to:
  /// **'Please select your date of birth'**
  String get pc_dob_required;

  /// No description provided for @pc_enter_full_name.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get pc_enter_full_name;

  /// No description provided for @pc_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get pc_female;

  /// No description provided for @pc_gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get pc_gender;

  /// No description provided for @pc_gender_required.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get pc_gender_required;

  /// No description provided for @pc_intro.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile to get personalized content and exclusive features.'**
  String get pc_intro;

  /// No description provided for @pc_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get pc_male;

  /// No description provided for @pc_name_min.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get pc_name_min;

  /// No description provided for @pc_name_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pc_name_required;

  /// No description provided for @pc_nationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get pc_nationality;

  /// No description provided for @pc_nationality_required.
  ///
  /// In en, this message translates to:
  /// **'Please select your nationality'**
  String get pc_nationality_required;

  /// No description provided for @pc_phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get pc_phone_number;

  /// No description provided for @pc_phone_optional.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get pc_phone_optional;

  /// No description provided for @pc_save_profile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get pc_save_profile;

  /// No description provided for @pc_search_country.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get pc_search_country;

  /// No description provided for @pc_select_dob.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get pc_select_dob;

  /// No description provided for @pc_select_nationality.
  ///
  /// In en, this message translates to:
  /// **'Select your nationality'**
  String get pc_select_nationality;

  /// No description provided for @pc_skip_body.
  ///
  /// In en, this message translates to:
  /// **'You can complete your profile anytime from the settings.'**
  String get pc_skip_body;

  /// No description provided for @pc_skip_title.
  ///
  /// In en, this message translates to:
  /// **'Skip Profile Completion?'**
  String get pc_skip_title;

  /// No description provided for @pc_tell_us.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get pc_tell_us;

  /// No description provided for @pc_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile:'**
  String get pc_update_failed;

  /// No description provided for @prof_change_picture.
  ///
  /// In en, this message translates to:
  /// **'Change profile picture'**
  String get prof_change_picture;

  /// No description provided for @prof_choose_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get prof_choose_gallery;

  /// No description provided for @prof_crop_photo.
  ///
  /// In en, this message translates to:
  /// **'Crop Profile Photo'**
  String get prof_crop_photo;

  /// No description provided for @prof_deactivate_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to deactivate account'**
  String get prof_deactivate_failed;

  /// No description provided for @prof_deactivated.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated. Log in anytime to come back!'**
  String get prof_deactivated;

  /// No description provided for @prof_delete_body.
  ///
  /// In en, this message translates to:
  /// **'After 30 days, all your data will be permanently removed and cannot be recovered.'**
  String get prof_delete_body;

  /// No description provided for @prof_delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get prof_delete_failed;

  /// No description provided for @prof_delete_sub.
  ///
  /// In en, this message translates to:
  /// **'Schedule permanent deletion. You have 30 days to change your mind.'**
  String get prof_delete_sub;

  /// No description provided for @prof_digits_only.
  ///
  /// In en, this message translates to:
  /// **'Digits only'**
  String get prof_digits_only;

  /// No description provided for @prof_end_session.
  ///
  /// In en, this message translates to:
  /// **'End this session on this device'**
  String get prof_end_session;

  /// No description provided for @prof_enter_phone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get prof_enter_phone;

  /// No description provided for @prof_gender_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update gender'**
  String get prof_gender_update_failed;

  /// No description provided for @prof_gender_updated.
  ///
  /// In en, this message translates to:
  /// **'Gender updated'**
  String get prof_gender_updated;

  /// No description provided for @prof_linked_accounts.
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get prof_linked_accounts;

  /// No description provided for @prof_manage_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Manage sign-in methods'**
  String get prof_manage_sign_in;

  /// No description provided for @prof_missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get prof_missing;

  /// No description provided for @prof_not_set.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get prof_not_set;

  /// No description provided for @prof_official.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL'**
  String get prof_official;

  /// No description provided for @prof_phone_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update phone number'**
  String get prof_phone_update_failed;

  /// No description provided for @prof_phone_updated.
  ///
  /// In en, this message translates to:
  /// **'Phone number updated to'**
  String get prof_phone_updated;

  /// No description provided for @prof_picture_updated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get prof_picture_updated;

  /// No description provided for @prof_prefer_not.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get prof_prefer_not;

  /// No description provided for @prof_profile_picture.
  ///
  /// In en, this message translates to:
  /// **'Profile picture'**
  String get prof_profile_picture;

  /// No description provided for @prof_scheduled_deletion.
  ///
  /// In en, this message translates to:
  /// **'Account scheduled for deletion. Log in within 30 days to cancel.'**
  String get prof_scheduled_deletion;

  /// No description provided for @prof_select_gender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get prof_select_gender;

  /// No description provided for @prof_select_nationality.
  ///
  /// In en, this message translates to:
  /// **'Select Nationality'**
  String get prof_select_nationality;

  /// No description provided for @prof_sign_out_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get prof_sign_out_confirm;

  /// No description provided for @prof_take_break.
  ///
  /// In en, this message translates to:
  /// **'Take a Break'**
  String get prof_take_break;

  /// No description provided for @prof_take_break_body.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deactivated and hidden from other users.'**
  String get prof_take_break_body;

  /// No description provided for @prof_take_break_sub.
  ///
  /// In en, this message translates to:
  /// **'Deactivate your account temporarily. Log in anytime to come back.'**
  String get prof_take_break_sub;

  /// No description provided for @prof_take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get prof_take_photo;

  /// No description provided for @prof_update_password.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get prof_update_password;

  /// No description provided for @prof_update_phone.
  ///
  /// In en, this message translates to:
  /// **'Update Phone Number'**
  String get prof_update_phone;

  /// No description provided for @prof_upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image:'**
  String get prof_upload_failed;

  /// No description provided for @prof_user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get prof_user;

  /// No description provided for @prof_verified.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get prof_verified;

  /// No description provided for @res_coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get res_coming_soon;

  /// No description provided for @res_coming_soon_desc.
  ///
  /// In en, this message translates to:
  /// **'Summit documents and resources will be available here.'**
  String get res_coming_soon_desc;

  /// No description provided for @res_could_not_load.
  ///
  /// In en, this message translates to:
  /// **'Could not load resources'**
  String get res_could_not_load;

  /// No description provided for @res_view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get res_view;

  /// No description provided for @rs_album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get rs_album;

  /// No description provided for @rs_cancel_reply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get rs_cancel_reply;

  /// No description provided for @rs_checkin_code.
  ///
  /// In en, this message translates to:
  /// **'Check-In Code'**
  String get rs_checkin_code;

  /// No description provided for @rs_checkin_title.
  ///
  /// In en, this message translates to:
  /// **'Event Check-In'**
  String get rs_checkin_title;

  /// No description provided for @rs_comment_delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get rs_comment_delete_failed;

  /// No description provided for @rs_earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get rs_earlier;

  /// No description provided for @rs_evt_add_to_calendar.
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get rs_evt_add_to_calendar;

  /// No description provided for @rs_evt_proxy_failed.
  ///
  /// In en, this message translates to:
  /// **'Proxy registration failed. Try again.'**
  String get rs_evt_proxy_failed;

  /// No description provided for @rs_evt_proxy_success.
  ///
  /// In en, this message translates to:
  /// **'Proxy registration submitted!'**
  String get rs_evt_proxy_success;

  /// No description provided for @rs_evt_registration_failed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Try again.'**
  String get rs_evt_registration_failed;

  /// No description provided for @rs_evt_registration_success.
  ///
  /// In en, this message translates to:
  /// **'Registration successful!'**
  String get rs_evt_registration_success;

  /// No description provided for @rs_evt_send_thanks.
  ///
  /// In en, this message translates to:
  /// **'Send Thanks'**
  String get rs_evt_send_thanks;

  /// No description provided for @rs_evt_uploading_files.
  ///
  /// In en, this message translates to:
  /// **'Uploading files...'**
  String get rs_evt_uploading_files;

  /// No description provided for @rs_evt_view_ticket.
  ///
  /// In en, this message translates to:
  /// **'View Ticket'**
  String get rs_evt_view_ticket;

  /// No description provided for @rs_fb_comment_optional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get rs_fb_comment_optional;

  /// No description provided for @rs_fb_how_was.
  ///
  /// In en, this message translates to:
  /// **'How was this event?'**
  String get rs_fb_how_was;

  /// No description provided for @rs_fb_select_rating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get rs_fb_select_rating;

  /// No description provided for @rs_fb_share_hint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get rs_fb_share_hint;

  /// No description provided for @rs_fb_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get rs_fb_submit;

  /// No description provided for @rs_fb_submit_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit feedback. Please try again.'**
  String get rs_fb_submit_failed;

  /// No description provided for @rs_fb_submitted.
  ///
  /// In en, this message translates to:
  /// **'Your feedback has been submitted successfully.'**
  String get rs_fb_submitted;

  /// No description provided for @rs_fb_tap_star.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate'**
  String get rs_fb_tap_star;

  /// No description provided for @rs_fb_thank_you.
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get rs_fb_thank_you;

  /// No description provided for @rs_fb_thanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get rs_fb_thanks;

  /// No description provided for @rs_fb_title.
  ///
  /// In en, this message translates to:
  /// **'Event Feedback'**
  String get rs_fb_title;

  /// No description provided for @rs_go_back.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get rs_go_back;

  /// No description provided for @rs_notif_announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get rs_notif_announcements;

  /// No description provided for @rs_notif_check_connection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again'**
  String get rs_notif_check_connection;

  /// No description provided for @rs_notif_mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get rs_notif_mark_all_read;

  /// No description provided for @rs_notif_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get rs_notif_system;

  /// No description provided for @rs_our_agenda.
  ///
  /// In en, this message translates to:
  /// **'OUR AGENDA'**
  String get rs_our_agenda;

  /// No description provided for @rs_pdf_delete_download.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get rs_pdf_delete_download;

  /// No description provided for @rs_pdf_download_deleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded magazine deleted'**
  String get rs_pdf_download_deleted;

  /// No description provided for @rs_pdf_download_offline.
  ///
  /// In en, this message translates to:
  /// **'Download for offline'**
  String get rs_pdf_download_offline;

  /// No description provided for @rs_pdf_downloaded.
  ///
  /// In en, this message translates to:
  /// **'Magazine downloaded! Available offline.'**
  String get rs_pdf_downloaded;

  /// No description provided for @rs_pdf_downloaded_short.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get rs_pdf_downloaded_short;

  /// No description provided for @rs_pdf_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PDF:'**
  String get rs_pdf_load_failed;

  /// No description provided for @rs_pdf_rendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering PDF...'**
  String get rs_pdf_rendering;

  /// No description provided for @rs_tap_to_copy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get rs_tap_to_copy;

  /// No description provided for @rs_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rs_today;

  /// No description provided for @rs_zoom_in.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get rs_zoom_in;

  /// No description provided for @rs_zoom_out.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get rs_zoom_out;

  /// No description provided for @scan_align_frame.
  ///
  /// In en, this message translates to:
  /// **'Align the delegate QR inside the frame'**
  String get scan_align_frame;

  /// No description provided for @scan_checked_in.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get scan_checked_in;

  /// No description provided for @scan_code_example.
  ///
  /// In en, this message translates to:
  /// **'e.g. YD-2026-0001 or submission number'**
  String get scan_code_example;

  /// No description provided for @scan_code_hint.
  ///
  /// In en, this message translates to:
  /// **'Participant code or ticket ID'**
  String get scan_code_hint;

  /// No description provided for @scan_code_scanned.
  ///
  /// In en, this message translates to:
  /// **'Code already scanned'**
  String get scan_code_scanned;

  /// No description provided for @scan_credential_issued.
  ///
  /// In en, this message translates to:
  /// **'Credential issued'**
  String get scan_credential_issued;

  /// No description provided for @scan_credential_scanned.
  ///
  /// In en, this message translates to:
  /// **'Credential already scanned'**
  String get scan_credential_scanned;

  /// No description provided for @scan_credential_title.
  ///
  /// In en, this message translates to:
  /// **'Scan credential'**
  String get scan_credential_title;

  /// No description provided for @scan_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scan_date;

  /// No description provided for @scan_dup_used.
  ///
  /// In en, this message translates to:
  /// **'It may have already been used for check-in.'**
  String get scan_dup_used;

  /// No description provided for @scan_duplicate.
  ///
  /// In en, this message translates to:
  /// **'DUPLICATE'**
  String get scan_duplicate;

  /// No description provided for @scan_enter_code_error.
  ///
  /// In en, this message translates to:
  /// **'Please enter a participant code or ticket ID.'**
  String get scan_enter_code_error;

  /// No description provided for @scan_enter_code_title.
  ///
  /// In en, this message translates to:
  /// **'Enter participant code or ticket ID'**
  String get scan_enter_code_title;

  /// No description provided for @scan_enter_name_error.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name to search.'**
  String get scan_enter_name_error;

  /// No description provided for @scan_event_dates.
  ///
  /// In en, this message translates to:
  /// **'Event dates'**
  String get scan_event_dates;

  /// No description provided for @scan_first_scan.
  ///
  /// In en, this message translates to:
  /// **'FIRST SCAN'**
  String get scan_first_scan;

  /// No description provided for @scan_history_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load scan history.'**
  String get scan_history_load_failed;

  /// No description provided for @scan_history_title.
  ///
  /// In en, this message translates to:
  /// **'Scan history'**
  String get scan_history_title;

  /// No description provided for @scan_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get scan_location;

  /// No description provided for @scan_lookup_manually.
  ///
  /// In en, this message translates to:
  /// **'Can\'t scan? Look up manually'**
  String get scan_lookup_manually;

  /// No description provided for @scan_manual_lookup.
  ///
  /// In en, this message translates to:
  /// **'Manual Lookup'**
  String get scan_manual_lookup;

  /// No description provided for @scan_multi_dup_body.
  ///
  /// In en, this message translates to:
  /// **'This is unusual — please verify the person\'s identity manually.'**
  String get scan_multi_dup_body;

  /// No description provided for @scan_multiple_matches.
  ///
  /// In en, this message translates to:
  /// **'Multiple matches found'**
  String get scan_multiple_matches;

  /// No description provided for @scan_name_email_required.
  ///
  /// In en, this message translates to:
  /// **'Both name and email are required.'**
  String get scan_name_email_required;

  /// No description provided for @scan_name_required_hint.
  ///
  /// In en, this message translates to:
  /// **'Name (required)'**
  String get scan_name_required_hint;

  /// No description provided for @scan_nationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get scan_nationality;

  /// No description provided for @scan_nationality_hint.
  ///
  /// In en, this message translates to:
  /// **'Nationality (optional, e.g. BI, RW, KE)'**
  String get scan_nationality_hint;

  /// No description provided for @scan_no_scans.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get scan_no_scans;

  /// No description provided for @scan_no_scans_sub.
  ///
  /// In en, this message translates to:
  /// **'Scanned credentials will appear here.'**
  String get scan_no_scans_sub;

  /// No description provided for @scan_organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get scan_organization;

  /// No description provided for @scan_participant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get scan_participant;

  /// No description provided for @scan_participant_code.
  ///
  /// In en, this message translates to:
  /// **'Participant code'**
  String get scan_participant_code;

  /// No description provided for @scan_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get scan_phone;

  /// No description provided for @scan_proxy.
  ///
  /// In en, this message translates to:
  /// **'Registered by proxy'**
  String get scan_proxy;

  /// No description provided for @scan_qr_for.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code for'**
  String get scan_qr_for;

  /// No description provided for @scan_reference_id.
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get scan_reference_id;

  /// No description provided for @scan_registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get scan_registration;

  /// No description provided for @scan_reset_again.
  ///
  /// In en, this message translates to:
  /// **'Reset & Scan Again'**
  String get scan_reset_again;

  /// No description provided for @scan_revocation_reason.
  ///
  /// In en, this message translates to:
  /// **'Revocation reason'**
  String get scan_revocation_reason;

  /// No description provided for @scan_role_hint.
  ///
  /// In en, this message translates to:
  /// **'Role (optional, e.g. Participant, Moderator)'**
  String get scan_role_hint;

  /// No description provided for @scan_scanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get scan_scanned;

  /// No description provided for @scan_scanned_once.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get scan_scanned_once;

  /// No description provided for @scan_scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scan_scanner;

  /// No description provided for @scan_search_by_name.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get scan_search_by_name;

  /// No description provided for @scan_search_by_name_sub.
  ///
  /// In en, this message translates to:
  /// **'Enter the person\'s name. Optionally filter by nationality or role.'**
  String get scan_search_by_name_sub;

  /// No description provided for @scan_search_name_email.
  ///
  /// In en, this message translates to:
  /// **'Search by name and email'**
  String get scan_search_name_email;

  /// No description provided for @scan_search_name_email_sub.
  ///
  /// In en, this message translates to:
  /// **'Enter the person\'s full name and email address.'**
  String get scan_search_name_email_sub;

  /// No description provided for @scan_select_person.
  ///
  /// In en, this message translates to:
  /// **'Select the person to view their details.'**
  String get scan_select_person;

  /// No description provided for @scan_side_event.
  ///
  /// In en, this message translates to:
  /// **'Side event'**
  String get scan_side_event;

  /// No description provided for @scan_switch_camera.
  ///
  /// In en, this message translates to:
  /// **'Switch Camera'**
  String get scan_switch_camera;

  /// No description provided for @scan_tab_code.
  ///
  /// In en, this message translates to:
  /// **'By ID / Code'**
  String get scan_tab_code;

  /// No description provided for @scan_tab_name.
  ///
  /// In en, this message translates to:
  /// **'By Name'**
  String get scan_tab_name;

  /// No description provided for @scan_tab_name_email.
  ///
  /// In en, this message translates to:
  /// **'By Name & Email'**
  String get scan_tab_name_email;

  /// No description provided for @scan_times.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get scan_times;

  /// No description provided for @scan_toggle_flash.
  ///
  /// In en, this message translates to:
  /// **'Toggle Flash'**
  String get scan_toggle_flash;

  /// No description provided for @scan_until.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get scan_until;

  /// No description provided for @scan_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get scan_venue;

  /// No description provided for @scan_verified.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get scan_verified;

  /// No description provided for @scan_waitlisted.
  ///
  /// In en, this message translates to:
  /// **'Waitlisted'**
  String get scan_waitlisted;

  /// No description provided for @sec_could_not_change_password.
  ///
  /// In en, this message translates to:
  /// **'Could not change your password'**
  String get sec_could_not_change_password;

  /// No description provided for @sec_could_not_load_history.
  ///
  /// In en, this message translates to:
  /// **'Could not load login history'**
  String get sec_could_not_load_history;

  /// No description provided for @sec_could_not_load_sessions.
  ///
  /// In en, this message translates to:
  /// **'Could not load sessions'**
  String get sec_could_not_load_sessions;

  /// No description provided for @sec_could_not_revoke.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke this session'**
  String get sec_could_not_revoke;

  /// No description provided for @sec_current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get sec_current;

  /// No description provided for @sec_last_active.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get sec_last_active;

  /// No description provided for @sec_no_active_sessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get sec_no_active_sessions;

  /// No description provided for @sec_no_login_history.
  ///
  /// In en, this message translates to:
  /// **'No login history'**
  String get sec_no_login_history;

  /// No description provided for @sec_revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get sec_revoke;

  /// No description provided for @sec_revoke_confirm.
  ///
  /// In en, this message translates to:
  /// **'This will sign out this device. Continue?'**
  String get sec_revoke_confirm;

  /// No description provided for @sec_revoke_session.
  ///
  /// In en, this message translates to:
  /// **'Revoke session'**
  String get sec_revoke_session;

  /// No description provided for @sec_unknown_device.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get sec_unknown_device;

  /// No description provided for @st_breaking_news.
  ///
  /// In en, this message translates to:
  /// **'Breaking news'**
  String get st_breaking_news;

  /// No description provided for @st_could_not_load_prefs.
  ///
  /// In en, this message translates to:
  /// **'Could not load your notification settings'**
  String get st_could_not_load_prefs;

  /// No description provided for @st_could_not_save_pref.
  ///
  /// In en, this message translates to:
  /// **'Could not save that setting'**
  String get st_could_not_save_pref;

  /// No description provided for @st_email_notifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get st_email_notifications;

  /// No description provided for @st_engagement.
  ///
  /// In en, this message translates to:
  /// **'Replies and mentions'**
  String get st_engagement;

  /// No description provided for @st_event_reminders.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get st_event_reminders;

  /// No description provided for @st_live_alerts.
  ///
  /// In en, this message translates to:
  /// **'Live broadcast alerts'**
  String get st_live_alerts;

  /// No description provided for @st_messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get st_messages;

  /// No description provided for @st_new_issues.
  ///
  /// In en, this message translates to:
  /// **'New magazine issues'**
  String get st_new_issues;

  /// No description provided for @st_push_notifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get st_push_notifications;

  /// No description provided for @st_quiet_hours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get st_quiet_hours;

  /// No description provided for @st_quiet_hours_note.
  ///
  /// In en, this message translates to:
  /// **'Notifications are held back during these hours.'**
  String get st_quiet_hours_note;

  /// No description provided for @st_schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get st_schedule;

  /// No description provided for @st_topics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get st_topics;

  /// No description provided for @sup_additional_feedback.
  ///
  /// In en, this message translates to:
  /// **'Any additional feedback? (optional)'**
  String get sup_additional_feedback;

  /// No description provided for @sup_enter_message.
  ///
  /// In en, this message translates to:
  /// **'Please enter your message'**
  String get sup_enter_message;

  /// No description provided for @sup_enter_subject.
  ///
  /// In en, this message translates to:
  /// **'Please enter a subject'**
  String get sup_enter_subject;

  /// No description provided for @sup_failed_load_tickets.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tickets'**
  String get sup_failed_load_tickets;

  /// No description provided for @sup_failed_rating.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating:'**
  String get sup_failed_rating;

  /// No description provided for @sup_failed_to_send.
  ///
  /// In en, this message translates to:
  /// **'Failed to send:'**
  String get sup_failed_to_send;

  /// No description provided for @sup_failed_to_submit.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit:'**
  String get sup_failed_to_submit;

  /// No description provided for @sup_how_can_we_help.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get sup_how_can_we_help;

  /// No description provided for @sup_how_was_experience.
  ///
  /// In en, this message translates to:
  /// **'How was your support experience?'**
  String get sup_how_was_experience;

  /// No description provided for @sup_message.
  ///
  /// In en, this message translates to:
  /// **'MESSAGE'**
  String get sup_message;

  /// No description provided for @sup_message_hint.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue or question in detail…'**
  String get sup_message_hint;

  /// No description provided for @sup_message_min.
  ///
  /// In en, this message translates to:
  /// **'Please provide more details (at least 10 characters)'**
  String get sup_message_min;

  /// No description provided for @sup_my_tickets.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get sup_my_tickets;

  /// No description provided for @sup_new_ticket.
  ///
  /// In en, this message translates to:
  /// **'New ticket'**
  String get sup_new_ticket;

  /// No description provided for @sup_new_ticket_sub.
  ///
  /// In en, this message translates to:
  /// **'We usually reply within 24 hours'**
  String get sup_new_ticket_sub;

  /// No description provided for @sup_no_messages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get sup_no_messages;

  /// No description provided for @sup_no_subject.
  ///
  /// In en, this message translates to:
  /// **'No subject'**
  String get sup_no_subject;

  /// No description provided for @sup_no_tickets.
  ///
  /// In en, this message translates to:
  /// **'No support tickets'**
  String get sup_no_tickets;

  /// No description provided for @sup_no_tickets_sub.
  ///
  /// In en, this message translates to:
  /// **'Open a ticket above and our team will get back to you.'**
  String get sup_no_tickets_sub;

  /// No description provided for @sup_optional_comment.
  ///
  /// In en, this message translates to:
  /// **'Optional comment...'**
  String get sup_optional_comment;

  /// No description provided for @sup_please_rate.
  ///
  /// In en, this message translates to:
  /// **'Please rate your experience'**
  String get sup_please_rate;

  /// No description provided for @sup_rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get sup_rate;

  /// No description provided for @sup_rate_experience_title.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Experience'**
  String get sup_rate_experience_title;

  /// No description provided for @sup_rate_title.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Support'**
  String get sup_rate_title;

  /// No description provided for @sup_respond_24h.
  ///
  /// In en, this message translates to:
  /// **'We typically respond within 24 hours'**
  String get sup_respond_24h;

  /// No description provided for @sup_start_new_ticket.
  ///
  /// In en, this message translates to:
  /// **'Start New Ticket'**
  String get sup_start_new_ticket;

  /// No description provided for @sup_status_closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get sup_status_closed;

  /// No description provided for @sup_status_in_progress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get sup_status_in_progress;

  /// No description provided for @sup_status_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sup_status_open;

  /// No description provided for @sup_status_resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get sup_status_resolved;

  /// No description provided for @sup_subject.
  ///
  /// In en, this message translates to:
  /// **'SUBJECT'**
  String get sup_subject;

  /// No description provided for @sup_subject_hint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of your issue'**
  String get sup_subject_hint;

  /// No description provided for @sup_subject_min.
  ///
  /// In en, this message translates to:
  /// **'Subject must be at least 3 characters'**
  String get sup_subject_min;

  /// No description provided for @sup_submit_request.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get sup_submit_request;

  /// No description provided for @sup_submitted.
  ///
  /// In en, this message translates to:
  /// **'Support ticket submitted! We\'ll respond via email.'**
  String get sup_submitted;

  /// No description provided for @sup_thanks_feedback.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get sup_thanks_feedback;

  /// No description provided for @sup_ticket_closed.
  ///
  /// In en, this message translates to:
  /// **'This ticket is closed'**
  String get sup_ticket_closed;

  /// No description provided for @sup_ticket_resolved.
  ///
  /// In en, this message translates to:
  /// **'Ticket Resolved'**
  String get sup_ticket_resolved;

  /// No description provided for @sup_ticket_resolved_prefix.
  ///
  /// In en, this message translates to:
  /// **'Your ticket'**
  String get sup_ticket_resolved_prefix;

  /// No description provided for @sup_ticket_resolved_suffix.
  ///
  /// In en, this message translates to:
  /// **'has been resolved. How was your experience?'**
  String get sup_ticket_resolved_suffix;

  /// No description provided for @sup_ticket_title.
  ///
  /// In en, this message translates to:
  /// **'Support Ticket'**
  String get sup_ticket_title;

  /// No description provided for @sup_title.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sup_title;

  /// No description provided for @sup_updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get sup_updated;

  /// No description provided for @sup_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sup_yesterday;

  /// No description provided for @sup_you_rated.
  ///
  /// In en, this message translates to:
  /// **'You rated this'**
  String get sup_you_rated;

  /// No description provided for @tk_attendee.
  ///
  /// In en, this message translates to:
  /// **'Attendee'**
  String get tk_attendee;

  /// No description provided for @tk_checked_in.
  ///
  /// In en, this message translates to:
  /// **'CHECKED IN'**
  String get tk_checked_in;

  /// No description provided for @tk_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load ticket. Please try again.'**
  String get tk_load_failed;

  /// No description provided for @tk_no_qr.
  ///
  /// In en, this message translates to:
  /// **'No QR data'**
  String get tk_no_qr;

  /// No description provided for @tk_scan_checkin.
  ///
  /// In en, this message translates to:
  /// **'Scan for Check-in'**
  String get tk_scan_checkin;

  /// No description provided for @tk_share.
  ///
  /// In en, this message translates to:
  /// **'Share Ticket'**
  String get tk_share;

  /// No description provided for @tk_share_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share ticket.'**
  String get tk_share_failed;

  /// No description provided for @tk_share_text.
  ///
  /// In en, this message translates to:
  /// **'My ticket for'**
  String get tk_share_text;

  /// No description provided for @tk_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tk_status;

  /// No description provided for @tk_title.
  ///
  /// In en, this message translates to:
  /// **'Event Ticket'**
  String get tk_title;

  /// No description provided for @tk_waitlisted.
  ///
  /// In en, this message translates to:
  /// **'WAITLISTED'**
  String get tk_waitlisted;

  /// No description provided for @vr_badge_notice.
  ///
  /// In en, this message translates to:
  /// **'Our team will review your application and may assign a different badge based on your profile.'**
  String get vr_badge_notice;

  /// No description provided for @vr_blue_badge.
  ///
  /// In en, this message translates to:
  /// **'Blue Badge'**
  String get vr_blue_badge;

  /// No description provided for @vr_blue_desc.
  ///
  /// In en, this message translates to:
  /// **'Verified professionals and notable individuals'**
  String get vr_blue_desc;

  /// No description provided for @vr_code_sent_to.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to'**
  String get vr_code_sent_to;

  /// No description provided for @vr_email_verified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get vr_email_verified;

  /// No description provided for @vr_email_verified_snack.
  ///
  /// In en, this message translates to:
  /// **'Email verified!'**
  String get vr_email_verified_snack;

  /// No description provided for @vr_enter_code.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get vr_enter_code;

  /// No description provided for @vr_enter_full_legal_name.
  ///
  /// In en, this message translates to:
  /// **'Enter your full legal name'**
  String get vr_enter_full_legal_name;

  /// No description provided for @vr_full_legal_name.
  ///
  /// In en, this message translates to:
  /// **'Full Legal Name *'**
  String get vr_full_legal_name;

  /// No description provided for @vr_full_name_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get vr_full_name_required;

  /// No description provided for @vr_gender_label.
  ///
  /// In en, this message translates to:
  /// **'Gender *'**
  String get vr_gender_label;

  /// No description provided for @vr_get_code.
  ///
  /// In en, this message translates to:
  /// **'Get Code'**
  String get vr_get_code;

  /// No description provided for @vr_go_back.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get vr_go_back;

  /// No description provided for @vr_gold_badge.
  ///
  /// In en, this message translates to:
  /// **'Gold Badge'**
  String get vr_gold_badge;

  /// No description provided for @vr_gold_desc.
  ///
  /// In en, this message translates to:
  /// **'VIPs, Government Officials, Ambassadors'**
  String get vr_gold_desc;

  /// No description provided for @vr_green_badge.
  ///
  /// In en, this message translates to:
  /// **'Green Badge'**
  String get vr_green_badge;

  /// No description provided for @vr_green_desc.
  ///
  /// In en, this message translates to:
  /// **'Verified community members and contributors'**
  String get vr_green_desc;

  /// No description provided for @vr_in_review.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get vr_in_review;

  /// No description provided for @vr_intro.
  ///
  /// In en, this message translates to:
  /// **'Apply for a verified badge to stand out as an official representative or notable figure.'**
  String get vr_intro;

  /// No description provided for @vr_name_min.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters'**
  String get vr_name_min;

  /// No description provided for @vr_nationality_label.
  ///
  /// In en, this message translates to:
  /// **'Nationality *'**
  String get vr_nationality_label;

  /// No description provided for @vr_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get vr_other;

  /// No description provided for @vr_pending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get vr_pending;

  /// No description provided for @vr_pending_body.
  ///
  /// In en, this message translates to:
  /// **'Your verification request has been submitted. Reviews usually take up to 5 working days.'**
  String get vr_pending_body;

  /// No description provided for @vr_position.
  ///
  /// In en, this message translates to:
  /// **'Current Position/Role *'**
  String get vr_position;

  /// No description provided for @vr_position_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Ambassador, Director, Minister'**
  String get vr_position_hint;

  /// No description provided for @vr_position_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current position'**
  String get vr_position_required;

  /// No description provided for @vr_progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get vr_progress;

  /// No description provided for @vr_request_submitted.
  ///
  /// In en, this message translates to:
  /// **'Request submitted!'**
  String get vr_request_submitted;

  /// No description provided for @vr_request_submitted_body.
  ///
  /// In en, this message translates to:
  /// **'Your verification request has been submitted successfully. Our team will review it within 24 hours and you\'ll be notified of the decision.'**
  String get vr_request_submitted_body;

  /// No description provided for @vr_review_notice.
  ///
  /// In en, this message translates to:
  /// **'Review typically takes up to 24 hours. You\'ll be notified once your request is reviewed.'**
  String get vr_review_notice;

  /// No description provided for @vr_select_badge_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose the badge type that best represents your role'**
  String get vr_select_badge_hint;

  /// No description provided for @vr_select_badge_required.
  ///
  /// In en, this message translates to:
  /// **'Please select a badge type'**
  String get vr_select_badge_required;

  /// No description provided for @vr_select_badge_type.
  ///
  /// In en, this message translates to:
  /// **'Select Badge Type *'**
  String get vr_select_badge_type;

  /// No description provided for @vr_select_gender.
  ///
  /// In en, this message translates to:
  /// **'Select your gender'**
  String get vr_select_gender;

  /// No description provided for @vr_select_title.
  ///
  /// In en, this message translates to:
  /// **'Select your title'**
  String get vr_select_title;

  /// No description provided for @vr_send_code_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code. Please check your connection and try again.'**
  String get vr_send_code_failed;

  /// No description provided for @vr_social_hint.
  ///
  /// In en, this message translates to:
  /// **'Tap a platform to add your profile'**
  String get vr_social_hint;

  /// No description provided for @vr_social_media.
  ///
  /// In en, this message translates to:
  /// **'Social Media (Optional)'**
  String get vr_social_media;

  /// No description provided for @vr_step_badge.
  ///
  /// In en, this message translates to:
  /// **'Badge issued'**
  String get vr_step_badge;

  /// No description provided for @vr_step_badge_sub.
  ///
  /// In en, this message translates to:
  /// **'Verified badge appears on your profile'**
  String get vr_step_badge_sub;

  /// No description provided for @vr_step_docs.
  ///
  /// In en, this message translates to:
  /// **'Documents submitted'**
  String get vr_step_docs;

  /// No description provided for @vr_step_docs_sub.
  ///
  /// In en, this message translates to:
  /// **'Government ID + selfie'**
  String get vr_step_docs_sub;

  /// No description provided for @vr_step_review.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get vr_step_review;

  /// No description provided for @vr_step_review_sub.
  ///
  /// In en, this message translates to:
  /// **'Our team is checking your documents'**
  String get vr_step_review_sub;

  /// No description provided for @vr_submit_request.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get vr_submit_request;

  /// No description provided for @vr_supporting_doc.
  ///
  /// In en, this message translates to:
  /// **'Supporting document'**
  String get vr_supporting_doc;

  /// No description provided for @vr_supporting_doc_hint.
  ///
  /// In en, this message translates to:
  /// **'An appointment letter, official ID or press card helps us verify you faster.'**
  String get vr_supporting_doc_hint;

  /// No description provided for @vr_tap_upload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload image'**
  String get vr_tap_upload;

  /// No description provided for @vr_title_label.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get vr_title_label;

  /// No description provided for @vr_title_required.
  ///
  /// In en, this message translates to:
  /// **'Please select your title'**
  String get vr_title_required;

  /// No description provided for @vr_verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get vr_verification;

  /// No description provided for @vr_verify_email_to_submit.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email to submit'**
  String get vr_verify_email_to_submit;

  /// No description provided for @vr_work_email.
  ///
  /// In en, this message translates to:
  /// **'Work/Professional Email *'**
  String get vr_work_email;

  /// No description provided for @vr_work_email_hint.
  ///
  /// In en, this message translates to:
  /// **'Use your professional or organizational email (not personal Gmail/Yahoo)'**
  String get vr_work_email_hint;

  /// No description provided for @w_qa_ask_hint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question...'**
  String get w_qa_ask_hint;

  /// No description provided for @w_qa_be_first.
  ///
  /// In en, this message translates to:
  /// **'Be the first to ask!'**
  String get w_qa_be_first;

  /// No description provided for @w_qa_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load questions.'**
  String get w_qa_load_failed;

  /// No description provided for @w_qa_none.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get w_qa_none;

  /// No description provided for @w_qa_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh questions'**
  String get w_qa_refresh;

  /// No description provided for @w_qa_submit_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit question. Try again.'**
  String get w_qa_submit_failed;

  /// No description provided for @w_qa_title.
  ///
  /// In en, this message translates to:
  /// **'Live Q&A'**
  String get w_qa_title;

  /// No description provided for @w_reason_label.
  ///
  /// In en, this message translates to:
  /// **'Reason:'**
  String get w_reason_label;

  /// No description provided for @w_reference_number.
  ///
  /// In en, this message translates to:
  /// **'Your reference number:'**
  String get w_reference_number;

  /// No description provided for @w_reply_to.
  ///
  /// In en, this message translates to:
  /// **'Reply to'**
  String get w_reply_to;

  /// No description provided for @w_submit_appeal.
  ///
  /// In en, this message translates to:
  /// **'Submit an Appeal'**
  String get w_submit_appeal;

  /// No description provided for @w_update_mandatory.
  ///
  /// In en, this message translates to:
  /// **'This update is required to continue using the app.'**
  String get w_update_mandatory;

  /// No description provided for @w_update_new_features.
  ///
  /// In en, this message translates to:
  /// **'New features and improvements await you!'**
  String get w_update_new_features;

  /// No description provided for @w_verification_approved.
  ///
  /// In en, this message translates to:
  /// **'Your verification request has been approved!'**
  String get w_verification_approved;

  /// No description provided for @w_verification_not_approved.
  ///
  /// In en, this message translates to:
  /// **'Verification Not Approved'**
  String get w_verification_not_approved;

  /// No description provided for @w_version_available_prefix.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get w_version_available_prefix;

  /// No description provided for @w_version_available_suffix.
  ///
  /// In en, this message translates to:
  /// **'is now available.'**
  String get w_version_available_suffix;

  /// No description provided for @w_whats_new_sub.
  ///
  /// In en, this message translates to:
  /// **'Here is what changed in this release'**
  String get w_whats_new_sub;

  /// No description provided for @wx_add_city.
  ///
  /// In en, this message translates to:
  /// **'Add city'**
  String get wx_add_city;

  /// No description provided for @wx_city_name.
  ///
  /// In en, this message translates to:
  /// **'City name'**
  String get wx_city_name;

  /// No description provided for @wx_could_not_load.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get wx_could_not_load;

  /// No description provided for @wx_high.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get wx_high;

  /// No description provided for @wx_low.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get wx_low;

  /// No description provided for @wx_no_rain.
  ///
  /// In en, this message translates to:
  /// **'No rain expected — clear skies ahead.'**
  String get wx_no_rain;

  /// No description provided for @wx_no_results.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get wx_no_results;

  /// No description provided for @wx_rain_chance.
  ///
  /// In en, this message translates to:
  /// **'chance of rain in the next few days — pack an umbrella.'**
  String get wx_rain_chance;

  /// No description provided for @wx_rain_expected.
  ///
  /// In en, this message translates to:
  /// **'Rain expected in the next few days — pack an umbrella.'**
  String get wx_rain_expected;

  /// No description provided for @wx_rain_now.
  ///
  /// In en, this message translates to:
  /// **'Rain right now — carry an umbrella!'**
  String get wx_rain_now;

  /// No description provided for @wx_remove_city.
  ///
  /// In en, this message translates to:
  /// **'Remove City'**
  String get wx_remove_city;

  /// No description provided for @wx_remove_city_prefix.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get wx_remove_city_prefix;

  /// No description provided for @wx_remove_city_suffix.
  ///
  /// In en, this message translates to:
  /// **'from your cities?'**
  String get wx_remove_city_suffix;

  /// No description provided for @wx_search_city.
  ///
  /// In en, this message translates to:
  /// **'Search for a city...'**
  String get wx_search_city;

  /// No description provided for @yda_application_submitted.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted'**
  String get yda_application_submitted;

  /// No description provided for @yda_application_submitted_excl.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted!'**
  String get yda_application_submitted_excl;

  /// No description provided for @yda_apply_for.
  ///
  /// In en, this message translates to:
  /// **'Apply for'**
  String get yda_apply_for;

  /// No description provided for @yda_back_to.
  ///
  /// In en, this message translates to:
  /// **'Back to'**
  String get yda_back_to;

  /// No description provided for @yda_email_not_verified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get yda_email_not_verified;

  /// No description provided for @yda_email_sent.
  ///
  /// In en, this message translates to:
  /// **'A confirmation email has been sent to your email address.'**
  String get yda_email_sent;

  /// No description provided for @yda_email_verified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get yda_email_verified;

  /// No description provided for @yda_fix_errors.
  ///
  /// In en, this message translates to:
  /// **'Please fix the errors highlighted in red below.'**
  String get yda_fix_errors;

  /// No description provided for @yda_fix_issues.
  ///
  /// In en, this message translates to:
  /// **'Please fix the following issues:'**
  String get yda_fix_issues;

  /// No description provided for @yda_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get yda_invalid_email;

  /// No description provided for @yda_invalid_format.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get yda_invalid_format;

  /// No description provided for @yda_phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get yda_phone_number;

  /// No description provided for @yda_position_role.
  ///
  /// In en, this message translates to:
  /// **'Position / Role'**
  String get yda_position_role;

  /// No description provided for @yda_search_country.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get yda_search_country;

  /// No description provided for @yda_select_at_least_one.
  ///
  /// In en, this message translates to:
  /// **'Select at least one'**
  String get yda_select_at_least_one;

  /// No description provided for @yda_select_position.
  ///
  /// In en, this message translates to:
  /// **'Select position'**
  String get yda_select_position;

  /// No description provided for @yda_select_title.
  ///
  /// In en, this message translates to:
  /// **'Select title'**
  String get yda_select_title;

  /// No description provided for @yda_side_events.
  ///
  /// In en, this message translates to:
  /// **'Side Events'**
  String get yda_side_events;

  /// No description provided for @yda_side_events_hint.
  ///
  /// In en, this message translates to:
  /// **'Choose one event you would like to attend'**
  String get yda_side_events_hint;

  /// No description provided for @yda_step_docs.
  ///
  /// In en, this message translates to:
  /// **'If accepted, upload the required documents'**
  String get yda_step_docs;

  /// No description provided for @yda_step_notify.
  ///
  /// In en, this message translates to:
  /// **'You will receive a notification with the decision'**
  String get yda_step_notify;

  /// No description provided for @yda_step_review.
  ///
  /// In en, this message translates to:
  /// **'Our team will review your application'**
  String get yda_step_review;

  /// No description provided for @yda_submission_error.
  ///
  /// In en, this message translates to:
  /// **'Submission Error'**
  String get yda_submission_error;

  /// No description provided for @yda_submit_application.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get yda_submit_application;

  /// No description provided for @yda_submitted_desc.
  ///
  /// In en, this message translates to:
  /// **'Your application has been successfully received and is being processed. We will notify you as soon as a decision has been made.'**
  String get yda_submitted_desc;

  /// No description provided for @yda_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get yda_title;

  /// No description provided for @yda_verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get yda_verify;

  /// No description provided for @yda_verify_email_first.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address before applying.'**
  String get yda_verify_email_first;

  /// No description provided for @yda_what_happens_next.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get yda_what_happens_next;

  /// No description provided for @ydc_event_date.
  ///
  /// In en, this message translates to:
  /// **'Event date'**
  String get ydc_event_date;

  /// No description provided for @ydc_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load credential.'**
  String get ydc_load_failed;

  /// No description provided for @ydc_my_credential.
  ///
  /// In en, this message translates to:
  /// **'My credential'**
  String get ydc_my_credential;

  /// No description provided for @ydc_nationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get ydc_nationality;

  /// No description provided for @ydc_organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get ydc_organization;

  /// No description provided for @ydc_pdf_unavailable.
  ///
  /// In en, this message translates to:
  /// **'PDF download is currently unavailable'**
  String get ydc_pdf_unavailable;

  /// No description provided for @ydc_position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get ydc_position;

  /// No description provided for @ydc_revoked.
  ///
  /// In en, this message translates to:
  /// **'Credential Revoked'**
  String get ydc_revoked;

  /// No description provided for @ydc_revoked_desc.
  ///
  /// In en, this message translates to:
  /// **'This credential is no longer valid.'**
  String get ydc_revoked_desc;

  /// No description provided for @ydc_role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get ydc_role;

  /// No description provided for @ydc_side_event.
  ///
  /// In en, this message translates to:
  /// **'Side event'**
  String get ydc_side_event;

  /// No description provided for @ydc_works_offline.
  ///
  /// In en, this message translates to:
  /// **'Works offline — show at every venue gate.'**
  String get ydc_works_offline;

  /// No description provided for @ydd_accepted_formats.
  ///
  /// In en, this message translates to:
  /// **'Accepted formats: PDF, JPG, PNG  •  Max 5MB per file'**
  String get ydd_accepted_formats;

  /// No description provided for @ydd_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get ydd_camera;

  /// No description provided for @ydd_documents_submitted.
  ///
  /// In en, this message translates to:
  /// **'Documents Submitted'**
  String get ydd_documents_submitted;

  /// No description provided for @ydd_documents_uploaded.
  ///
  /// In en, this message translates to:
  /// **'Documents Uploaded'**
  String get ydd_documents_uploaded;

  /// No description provided for @ydd_email_confirmation.
  ///
  /// In en, this message translates to:
  /// **'You will also receive an email confirmation with your verification status.'**
  String get ydd_email_confirmation;

  /// No description provided for @ydd_face_visible.
  ///
  /// In en, this message translates to:
  /// **'Make sure your face is clearly visible and well-lit.'**
  String get ydd_face_visible;

  /// No description provided for @ydd_file_too_large.
  ///
  /// In en, this message translates to:
  /// **'File too large'**
  String get ydd_file_too_large;

  /// No description provided for @ydd_files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get ydd_files;

  /// No description provided for @ydd_formats_hint.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG  •  Max 5MB'**
  String get ydd_formats_hint;

  /// No description provided for @ydd_id_or_passport.
  ///
  /// In en, this message translates to:
  /// **'Please upload either your national ID card or your passport.'**
  String get ydd_id_or_passport;

  /// No description provided for @ydd_image_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get ydd_image_load_failed;

  /// No description provided for @ydd_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load. Please try again.'**
  String get ydd_load_failed;

  /// No description provided for @ydd_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get ydd_locked;

  /// No description provided for @ydd_no_application.
  ///
  /// In en, this message translates to:
  /// **'No application found.'**
  String get ydd_no_application;

  /// No description provided for @ydd_passport_photo.
  ///
  /// In en, this message translates to:
  /// **'Passport Photo'**
  String get ydd_passport_photo;

  /// No description provided for @ydd_photo_source_hint.
  ///
  /// In en, this message translates to:
  /// **'Take a live photo or choose from gallery'**
  String get ydd_photo_source_hint;

  /// No description provided for @ydd_protected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get ydd_protected;

  /// No description provided for @ydd_rejection_reason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason:'**
  String get ydd_rejection_reason;

  /// No description provided for @ydd_replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get ydd_replace;

  /// No description provided for @ydd_required_documents.
  ///
  /// In en, this message translates to:
  /// **'Required documents'**
  String get ydd_required_documents;

  /// No description provided for @ydd_retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get ydd_retake;

  /// No description provided for @ydd_reupload_required.
  ///
  /// In en, this message translates to:
  /// **'Re-upload required:'**
  String get ydd_reupload_required;

  /// No description provided for @ydd_reupload_this.
  ///
  /// In en, this message translates to:
  /// **'Re-upload This Document'**
  String get ydd_reupload_this;

  /// No description provided for @ydd_review_photo.
  ///
  /// In en, this message translates to:
  /// **'Review Photo'**
  String get ydd_review_photo;

  /// No description provided for @ydd_secure_preview.
  ///
  /// In en, this message translates to:
  /// **'Secure preview'**
  String get ydd_secure_preview;

  /// No description provided for @ydd_secure_preview_blocked.
  ///
  /// In en, this message translates to:
  /// **'Secure preview — Screenshots blocked'**
  String get ydd_secure_preview_blocked;

  /// No description provided for @ydd_status_approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get ydd_status_approved;

  /// No description provided for @ydd_status_refresh_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the document status'**
  String get ydd_status_refresh_failed;

  /// No description provided for @ydd_status_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected — re-upload'**
  String get ydd_status_rejected;

  /// No description provided for @ydd_status_under_review.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get ydd_status_under_review;

  /// No description provided for @ydd_step_credential.
  ///
  /// In en, this message translates to:
  /// **'Once approved, your credential will be issued'**
  String get ydd_step_credential;

  /// No description provided for @ydd_step_notify.
  ///
  /// In en, this message translates to:
  /// **'You\'ll receive a notification once verified'**
  String get ydd_step_notify;

  /// No description provided for @ydd_step_rejected.
  ///
  /// In en, this message translates to:
  /// **'If any document is rejected, you can re-upload'**
  String get ydd_step_rejected;

  /// No description provided for @ydd_step_review.
  ///
  /// In en, this message translates to:
  /// **'Our team will review your documents'**
  String get ydd_step_review;

  /// No description provided for @ydd_submit_failed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed. Please try again.'**
  String get ydd_submit_failed;

  /// No description provided for @ydd_submitted_desc.
  ///
  /// In en, this message translates to:
  /// **'Your documents have been submitted for verification.'**
  String get ydd_submitted_desc;

  /// No description provided for @ydd_under_review_banner.
  ///
  /// In en, this message translates to:
  /// **'Your documents are under review'**
  String get ydd_under_review_banner;

  /// No description provided for @ydd_upload_document.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get ydd_upload_document;

  /// No description provided for @ydd_upload_documents.
  ///
  /// In en, this message translates to:
  /// **'Upload Documents'**
  String get ydd_upload_documents;

  /// No description provided for @ydd_upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get ydd_upload_failed;

  /// No description provided for @ydd_upload_success.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded successfully.'**
  String get ydd_upload_success;

  /// No description provided for @ydd_use_photo.
  ///
  /// In en, this message translates to:
  /// **'Use This Photo'**
  String get ydd_use_photo;

  /// No description provided for @ydd_what_happens_next.
  ///
  /// In en, this message translates to:
  /// **'What Happens Next'**
  String get ydd_what_happens_next;

  /// No description provided for @ydm_about_event.
  ///
  /// In en, this message translates to:
  /// **'About the Event'**
  String get ydm_about_event;

  /// No description provided for @ydm_accepted_after.
  ///
  /// In en, this message translates to:
  /// **'application has been accepted!'**
  String get ydm_accepted_after;

  /// No description provided for @ydm_accepted_before.
  ///
  /// In en, this message translates to:
  /// **'Your'**
  String get ydm_accepted_before;

  /// No description provided for @ydm_accepted_upload_to_proceed.
  ///
  /// In en, this message translates to:
  /// **'Your application has been accepted.\nPlease upload your documents to proceed.'**
  String get ydm_accepted_upload_to_proceed;

  /// No description provided for @ydm_access_denied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get ydm_access_denied;

  /// No description provided for @ydm_action_required.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get ydm_action_required;

  /// No description provided for @ydm_application_status.
  ///
  /// In en, this message translates to:
  /// **'Application Status'**
  String get ydm_application_status;

  /// No description provided for @ydm_apply_again.
  ///
  /// In en, this message translates to:
  /// **'Apply Again'**
  String get ydm_apply_again;

  /// No description provided for @ydm_apply_now.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get ydm_apply_now;

  /// No description provided for @ydm_banned.
  ///
  /// In en, this message translates to:
  /// **'You have been banned from this programme.'**
  String get ydm_banned;

  /// No description provided for @ydm_call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get ydm_call;

  /// No description provided for @ydm_check_email_credential.
  ///
  /// In en, this message translates to:
  /// **'Check your email for more details about your credential.'**
  String get ydm_check_email_credential;

  /// No description provided for @ydm_congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get ydm_congratulations;

  /// No description provided for @ydm_continue_to_application.
  ///
  /// In en, this message translates to:
  /// **'Continue to Application'**
  String get ydm_continue_to_application;

  /// No description provided for @ydm_credential_revoked.
  ///
  /// In en, this message translates to:
  /// **'Credential revoked'**
  String get ydm_credential_revoked;

  /// No description provided for @ydm_credential_revoked_msg.
  ///
  /// In en, this message translates to:
  /// **'Your credential has been revoked and can no longer be used.'**
  String get ydm_credential_revoked_msg;

  /// No description provided for @ydm_credential_revoked_title.
  ///
  /// In en, this message translates to:
  /// **'Your Credential Has Been Revoked'**
  String get ydm_credential_revoked_title;

  /// No description provided for @ydm_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ydm_date;

  /// No description provided for @ydm_digital_id_msg.
  ///
  /// In en, this message translates to:
  /// **'Show it at every venue gate — it works offline.'**
  String get ydm_digital_id_msg;

  /// No description provided for @ydm_digital_id_ready.
  ///
  /// In en, this message translates to:
  /// **'Your digital ID is ready'**
  String get ydm_digital_id_ready;

  /// No description provided for @ydm_dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get ydm_dismiss;

  /// No description provided for @ydm_docs_need_attention.
  ///
  /// In en, this message translates to:
  /// **'Documents Need Attention'**
  String get ydm_docs_need_attention;

  /// No description provided for @ydm_docs_verified_id_ready.
  ///
  /// In en, this message translates to:
  /// **'Your documents have been verified and your Digital ID is ready!'**
  String get ydm_docs_verified_id_ready;

  /// No description provided for @ydm_documents_required.
  ///
  /// In en, this message translates to:
  /// **'Documents required'**
  String get ydm_documents_required;

  /// No description provided for @ydm_documents_required_msg.
  ///
  /// In en, this message translates to:
  /// **'Please upload your required documents to continue the process.'**
  String get ydm_documents_required_msg;

  /// No description provided for @ydm_documents_to_fix.
  ///
  /// In en, this message translates to:
  /// **'Documents to Fix'**
  String get ydm_documents_to_fix;

  /// No description provided for @ydm_eligibility.
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get ydm_eligibility;

  /// No description provided for @ydm_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get ydm_email;

  /// No description provided for @ydm_event_day.
  ///
  /// In en, this message translates to:
  /// **'Event Day'**
  String get ydm_event_day;

  /// No description provided for @ydm_event_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get ydm_event_venue;

  /// No description provided for @ydm_fix_documents.
  ///
  /// In en, this message translates to:
  /// **'Fix Documents'**
  String get ydm_fix_documents;

  /// No description provided for @ydm_id_card_ready.
  ///
  /// In en, this message translates to:
  /// **'Your ID Card is Ready!'**
  String get ydm_id_card_ready;

  /// No description provided for @ydm_key_highlights.
  ///
  /// In en, this message translates to:
  /// **'Key Highlights'**
  String get ydm_key_highlights;

  /// No description provided for @ydm_last_checked_at.
  ///
  /// In en, this message translates to:
  /// **'Last checked at'**
  String get ydm_last_checked_at;

  /// No description provided for @ydm_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get ydm_later;

  /// No description provided for @ydm_live_chat.
  ///
  /// In en, this message translates to:
  /// **'Live Chat'**
  String get ydm_live_chat;

  /// No description provided for @ydm_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get ydm_location;

  /// No description provided for @ydm_not_accepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get ydm_not_accepted;

  /// No description provided for @ydm_not_accepted_title.
  ///
  /// In en, this message translates to:
  /// **'Application not accepted'**
  String get ydm_not_accepted_title;

  /// No description provided for @ydm_not_approved.
  ///
  /// In en, this message translates to:
  /// **'Application Not Approved'**
  String get ydm_not_approved;

  /// No description provided for @ydm_not_eligible_reapply.
  ///
  /// In en, this message translates to:
  /// **'You are not eligible to re-apply for this programme.'**
  String get ydm_not_eligible_reapply;

  /// No description provided for @ydm_not_selected_msg.
  ///
  /// In en, this message translates to:
  /// **'Your application was not selected this time. Thank you for applying.'**
  String get ydm_not_selected_msg;

  /// No description provided for @ydm_privacy_agree.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Data Privacy Policy'**
  String get ydm_privacy_agree;

  /// No description provided for @ydm_privacy_read_accept.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept the privacy policy to continue.'**
  String get ydm_privacy_read_accept;

  /// No description provided for @ydm_progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get ydm_progress;

  /// No description provided for @ydm_promo_video.
  ///
  /// In en, this message translates to:
  /// **'Promotional Video'**
  String get ydm_promo_video;

  /// No description provided for @ydm_reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get ydm_reason;

  /// No description provided for @ydm_reference_number.
  ///
  /// In en, this message translates to:
  /// **'Reference Number'**
  String get ydm_reference_number;

  /// No description provided for @ydm_registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get ydm_registration;

  /// No description provided for @ydm_reupload.
  ///
  /// In en, this message translates to:
  /// **'Re-upload:'**
  String get ydm_reupload;

  /// No description provided for @ydm_reupload_affected_only.
  ///
  /// In en, this message translates to:
  /// **'Please re-upload only the affected document(s).'**
  String get ydm_reupload_affected_only;

  /// No description provided for @ydm_reupload_required.
  ///
  /// In en, this message translates to:
  /// **'Re-upload required'**
  String get ydm_reupload_required;

  /// No description provided for @ydm_revoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get ydm_revoked;

  /// No description provided for @ydm_side_events.
  ///
  /// In en, this message translates to:
  /// **'Side Events'**
  String get ydm_side_events;

  /// No description provided for @ydm_starts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get ydm_starts;

  /// No description provided for @ydm_status_check_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not check your application status'**
  String get ydm_status_check_failed;

  /// No description provided for @ydm_support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get ydm_support;

  /// No description provided for @ydm_to_deadline.
  ///
  /// In en, this message translates to:
  /// **'To deadline'**
  String get ydm_to_deadline;

  /// No description provided for @ydm_under_review_msg.
  ///
  /// In en, this message translates to:
  /// **'Our team is reviewing your application. You\'ll be notified of the decision.'**
  String get ydm_under_review_msg;

  /// No description provided for @ydm_under_review_title.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get ydm_under_review_title;

  /// No description provided for @ydm_upload_documents.
  ///
  /// In en, this message translates to:
  /// **'Upload Documents'**
  String get ydm_upload_documents;

  /// No description provided for @ydm_upload_required_docs.
  ///
  /// In en, this message translates to:
  /// **'Please upload your required documents to continue the process.'**
  String get ydm_upload_required_docs;

  /// No description provided for @ydm_upload_required_to_continue.
  ///
  /// In en, this message translates to:
  /// **'Please upload the required documents to continue your application.'**
  String get ydm_upload_required_to_continue;

  /// No description provided for @ydm_upload_your_documents.
  ///
  /// In en, this message translates to:
  /// **'Upload Your Documents'**
  String get ydm_upload_your_documents;

  /// No description provided for @ydm_venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get ydm_venue;

  /// No description provided for @ydm_verification_in_progress.
  ///
  /// In en, this message translates to:
  /// **'Verification in progress'**
  String get ydm_verification_in_progress;

  /// No description provided for @ydm_verification_msg.
  ///
  /// In en, this message translates to:
  /// **'Your documents are being checked. This usually takes a few working days.'**
  String get ydm_verification_msg;

  /// No description provided for @ydm_view_id_card.
  ///
  /// In en, this message translates to:
  /// **'View ID Card'**
  String get ydm_view_id_card;

  /// No description provided for @ydm_what_happens_next.
  ///
  /// In en, this message translates to:
  /// **'What Happens Next'**
  String get ydm_what_happens_next;

  /// No description provided for @ydm_your_application.
  ///
  /// In en, this message translates to:
  /// **'Your Application'**
  String get ydm_your_application;

  /// No description provided for @priority_agenda_footnote.
  ///
  /// In en, this message translates to:
  /// **'Select a priority to read its objectives, impact areas and current initiatives.'**
  String get priority_agenda_footnote;

  /// No description provided for @priority_agenda_intro.
  ///
  /// In en, this message translates to:
  /// **'Burundi\'s chairmanship of the African Union is built on three priorities. Each one has its own programme, objectives and current work.'**
  String get priority_agenda_intro;

  /// No description provided for @priority_agenda_open.
  ///
  /// In en, this message translates to:
  /// **'Read the full agenda'**
  String get priority_agenda_open;

  /// No description provided for @priority_label.
  ///
  /// In en, this message translates to:
  /// **'PRIORITY'**
  String get priority_label;
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
