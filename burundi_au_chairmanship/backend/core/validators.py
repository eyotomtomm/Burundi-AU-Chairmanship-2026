"""
File upload validators for the Be 4 Africa backend.
"""
import re
from django.core.exceptions import ValidationError
from django.conf import settings
import os


def validate_image_file(file):
    """
    Validate uploaded image file size, extension, and content type.
    """
    # Check file size
    if file.size > settings.MAX_IMAGE_SIZE:
        raise ValidationError(
            f'Image file too large. Maximum size is {settings.MAX_IMAGE_SIZE / (1024 * 1024)}MB.'
        )

    # Check extension
    ext = os.path.splitext(file.name)[1][1:].lower()
    if ext not in settings.ALLOWED_IMAGE_EXTENSIONS:
        raise ValidationError(
            f'Invalid image format. Allowed formats: {", ".join(settings.ALLOWED_IMAGE_EXTENSIONS)}'
        )

    # Validate actual file content (magic bytes)
    VALID_IMAGE_MIMES = {
        b'\xff\xd8\xff': 'jpg',       # JPEG
        b'\x89PNG': 'png',            # PNG
        b'GIF87a': 'gif',             # GIF87a
        b'GIF89a': 'gif',             # GIF89a
        b'RIFF': 'webp',             # WebP (starts with RIFF)
    }
    file.seek(0)
    header = file.read(8)
    file.seek(0)

    valid_content = False
    for magic, _ in VALID_IMAGE_MIMES.items():
        if header[:len(magic)] == magic:
            valid_content = True
            break

    if not valid_content:
        raise ValidationError('File content does not match a valid image format.')

    return file


def validate_document_file(file):
    """
    Validate uploaded document file size and extension.
    """
    # Check file size
    if file.size > settings.MAX_DOCUMENT_SIZE:
        raise ValidationError(
            f'Document file too large. Maximum size is {settings.MAX_DOCUMENT_SIZE / (1024 * 1024)}MB.'
        )

    # Check extension
    ext = os.path.splitext(file.name)[1][1:].lower()
    if ext not in settings.ALLOWED_DOCUMENT_EXTENSIONS:
        raise ValidationError(
            f'Invalid document format. Allowed formats: {", ".join(settings.ALLOWED_DOCUMENT_EXTENSIONS)}'
        )

    return file


def validate_fcm_token(token):
    """
    Validate Firebase Cloud Messaging token format.
    """
    if not token:
        raise ValidationError('FCM token cannot be empty')

    if not isinstance(token, str):
        raise ValidationError('FCM token must be a string')

    # FCM tokens are typically 152-163 characters
    if len(token) < 100 or len(token) > 200:
        raise ValidationError('Invalid FCM token format')

    return token


def validate_non_disposable_email(email):
    """
    Block disposable/temporary email providers at sign-up.
    Uses a large blocklist + pattern matching for comprehensive coverage.
    """
    if not email:
        raise ValidationError('Email cannot be empty')

    DISPOSABLE_DOMAINS = {
        # Major disposable email services
        'mailinator.com', 'guerrillamail.com', 'guerrillamail.info',
        'guerrillamail.de', 'guerrillamail.net', 'guerrillamail.org',
        'guerrillamailblock.com', 'grr.la',
        'tempmail.com', 'temp-mail.org', 'temp-mail.io', 'temp-mail.ru',
        'yopmail.com', 'yopmail.fr', 'yopmail.net', 'yopmail.gq',
        'throwaway.email', 'throwaway.com',
        'sharklasers.com', 'spam4.me', 'byom.de',
        'dispostable.com', 'mailnesia.com', 'maildrop.cc',
        'fakeinbox.com', 'trashmail.com', 'trashmail.me', 'trashmail.net',
        'getnada.com', 'tempinbox.com', 'tempr.email',
        'discard.email', 'discardmail.com', 'discardmail.de',
        'mailcatch.com', 'mailexpire.com', 'mailnull.com',
        'harakirimail.com', 'mailforspam.com', 'safetymail.info',
        'spamgourmet.com', 'mytemp.email', 'mohmal.com',
        'burnermail.io', 'inboxkitten.com',
        'mailsac.com', '10minutemail.com', '10minutemail.net',
        'minutemail.com', 'tempail.com',
        # Additional disposable providers
        'guerrillamail.biz', 'crazymailing.com', 'disposableemailaddresses.emailmiser.com',
        'emailondeck.com', 'emailsensei.com', 'emailtemporanea.com',
        'emailtemporanea.net', 'emailtemporar.ro', 'emailtemporario.com.br',
        'emailthe.net', 'emailtmp.com', 'emailwarden.com',
        'emailx.at.hm', 'emailxfer.com', 'emeil.in', 'emeil.ir',
        'emeraldwebmail.com', 'emkei.cz', 'eml.pp.ua',
        'emlhub.com', 'emlpro.com', 'emltmp.com',
        'enayu.com', 'enterto.com', 'ephemail.net',
        'etranquil.com', 'etranquil.net', 'etranquil.org',
        'evopo.com', 'ezfill.club', 'ezfill.com',
        'fakemailgenerator.com', 'fastacura.com', 'fastchevy.com',
        'fastchrysler.com', 'fastkawasaki.com', 'fastmazda.com',
        'fastnissan.com', 'fastsubaru.com', 'fastsuzuki.com',
        'fasttoyota.com', 'filzmail.com', 'fixmail.tk',
        'flyspam.com', 'foobarbot.net', 'forgetmail.com',
        'fr33mail.info', 'frapmail.com', 'freundin.ru',
        'frontfox.com', 'fuckingduh.com', 'fudgerub.com',
        'funkytash.com', 'furzaupp.de', 'fux0ringduh.com',
        'getairmail.com', 'getmails.eu', 'getonemail.com',
        'getonemail.net', 'ghosttexter.de', 'girlsundertheinfluence.com',
        'gishpuppy.com', 'goemailgo.com', 'gorillaswithdirtyarmpits.com',
        'gotmail.com', 'gotmail.net', 'gotmail.org',
        'haltospam.com', 'hmamail.com', 'hotpop.com',
        'hulapla.de', 'ieatspam.eu', 'ieatspam.info',
        'imgof.com', 'imstations.com', 'inbound.plus',
        'inbox.si', 'inboxalias.com', 'inboxclean.com',
        'inboxclean.org', 'inboxproxy.com', 'incognitomail.com',
        'incognitomail.net', 'incognitomail.org', 'insorg.org',
        'instantemailaddress.com', 'ipoo.org', 'irish2me.com',
        'iwi.net', 'jetable.com', 'jetable.fr.nf',
        'jetable.net', 'jetable.org', 'jnxjn.com',
        'jourrapide.com', 'junk1e.com', 'junkmail.com',
        'junkmail.ga', 'junkmail.gq', 'kasmail.com',
        'kaspop.com', 'keepmymail.com', 'killmail.com',
        'killmail.net', 'kimsdisk.com', 'kingsq.ga',
        'kir.ch.tc', 'klassmaster.com', 'klassmaster.net',
        'klzlk.com', 'kook.ml', 'kurzepost.de',
        'lackmail.net', 'lakelivingston.com', 'landmail.co',
        'lastmail.co', 'lastmail.com', 'lazyinbox.com',
        'letthemeatspam.com', 'lhsdv.com', 'lifebyfood.com',
        'link2mail.net', 'litedrop.com', 'loadby.us',
        'login-email.cf', 'login-email.ga', 'login-email.ml',
        'login-email.tk', 'lol.ovpn.to', 'lookugly.com',
        'lopl.co.cc', 'lortemail.dk', 'lovemeleaveme.com',
        'lr78.com', 'lroid.com', 'lukop.dk',
        'luv2.us', 'm4ilweb.info', 'maboard.com',
        'mail-filter.com', 'mail-temporaire.fr', 'mail.by',
        'mail.mezimages.net', 'mail.zp.ua', 'mail1a.de',
        'mail21.cc', 'mail2rss.org', 'mail333.com',
        'mail4trash.com', 'mailbidon.com', 'mailblocks.com',
        'mailbucket.org', 'mailcat.biz', 'mailcz.info',
        'mailde.de', 'mailde.info', 'maildx.com',
        'maileater.com', 'mailed.in', 'maileme101.com',
        'mailexpire.com', 'mailfa.tk', 'mailfree.ga',
        'mailfree.gq', 'mailfree.ml', 'mailfreeonline.com',
        'mailfs.com', 'mailguard.me', 'mailhazard.com',
        'mailhazard.us', 'mailhz.me', 'mailimate.com',
        'mailin8r.com', 'mailinater.com', 'mailinator.net',
        'mailinator.org', 'mailinator.us', 'mailinator2.com',
        'mailincubator.com', 'mailismagic.com', 'mailmate.com',
        'mailme.gq', 'mailme.ir', 'mailme.lv',
        'mailme24.com', 'mailmetrash.com', 'mailmoat.com',
        'mailms.com', 'mailnator.com', 'mailnull.com',
        'mailorg.org', 'mailpick.biz', 'mailproxsy.com',
        'mailquack.com', 'mailrock.biz', 'mailscrap.com',
        'mailshell.com', 'mailsiphon.com', 'mailslapping.com',
        'mailslite.com', 'mailtemp.info', 'mailtome.de',
        'mailtothis.com', 'mailtrash.net', 'mailtv.net',
        'mailtv.tv', 'mailzilla.com', 'mailzilla.org',
        'makemetheking.com', 'manifestgenerator.com', 'manybrain.com',
        'mbx.cc', 'mega.zik.dj', 'meinspamschutz.de',
        'meltmail.com', 'messagebeamer.de', 'mezimages.net',
        'mfsa.ru', 'mierdamail.com', 'migmail.pl',
        'migumail.com', 'minimail.eu', 'mintemail.com',
        'misterpinball.de', 'mmailisty.com', 'moakt.com',
        'mobi.web.id', 'mobileninja.co.uk', 'mohmal.in',
        'moncourrier.fr.nf', 'monemail.fr.nf', 'monmail.fr.nf',
        'monumentmail.com', 'msa.minsmail.com', 'mt2015.com',
        'mx0.wwwnew.eu', 'my10minutemail.com', 'myalias.pw',
        'mycard.net.ua', 'mycleaninbox.net', 'myemailboxy.com',
        'mymail-in.net', 'mymailoasis.com', 'mynetstore.de',
        'mypacks.net', 'mypartyclip.de', 'myphantom.com',
        'mysamp.de', 'myspaceinc.com', 'myspaceinc.net',
        'myspaceinc.org', 'myspacepimpedup.com', 'mytrashmail.com',
        'nabala.com', 'neomailbox.com', 'nepwk.com',
        'nervmich.net', 'nervtansen.de', 'netmails.com',
        'netmails.net', 'neverbox.com', 'no-spam.ws',
        'nobulk.com', 'noclickemail.com', 'nogmailspam.info',
        'nomail.pw', 'nomail.xl.cx', 'nomail2me.com',
        'nomorespamemails.com', 'nonspam.eu', 'nonspammer.de',
        'noref.in', 'nospam.ze.tc', 'nospam4.us',
        'nospamfor.us', 'nospammail.net', 'nospamthanks.info',
        'nothingtoseehere.ca', 'nowmymail.com', 'nurfuerspam.de',
        'nus.edu.sg', 'nwldx.com', 'objectmail.com',
        'obobbo.com', 'odnorazovoe.ru', 'oneoffemail.com',
        'oneoffmail.com', 'onewaymail.com', 'oopi.org',
        'ordinaryamerican.net', 'otherinbox.com', 'ourklips.com',
        'outlawspam.com', 'ovpn.to', 'owlpic.com',
        'pancakemail.com', 'paplease.com', 'pepbot.com',
        'pfui.ru', 'pimpedupmyspace.com', 'plexolan.de',
        'poczta.onet.pl', 'politikerclub.de', 'pookmail.com',
        'privacy.net', 'privy-mail.com', 'privymail.de',
        'proxymail.eu', 'prtnx.com', 'pseudomail.io',
        'punkass.com', 'putthisinyourspamdatabase.com',
        'qq.com', 'quickinbox.com',
        'rcpt.at', 'reallymymail.com', 'recode.me',
        'recursor.net', 'recyclemail.dk', 'regbypass.com',
        'regbypass.comsafe-mail.net', 'rejectmail.com',
        'reliable-mail.com', 'remail.cf', 'remail.ga',
        'rhyta.com', 'rklips.com', 'rmqkr.net',
        'royal.net', 'rppkn.com', 'rtrtr.com',
        'rustedtrombone.com', 's0ny.net', 'safe-mail.net',
        'safersignup.de', 'safetypost.de', 'sandelf.de',
        'saynotospams.com', 'scatmail.com', 'schafmail.de',
        'selfdestructingmail.com', 'sendspamhere.com', 'sharktastics.com',
        'shieldemail.com', 'shiftmail.com', 'shitmail.me',
        'shitmail.org', 'shitware.nl', 'shortmail.net',
        'sibmail.com', 'sinnlos-mail.de', 'siteposter.net',
        'skeefmail.com', 'slaskpost.se', 'slipry.net',
        'slopsbox.com', 'slowslow.de', 'slugmail.com',
        'smashmail.de', 'smellfear.com', 'snakemail.com',
        'sneakemail.com', 'sneakymail.de', 'snkmail.com',
        'sofimail.com', 'sofort-mail.de', 'softpls.asia',
        'sogetthis.com', 'soodonims.com', 'spam.la',
        'spam.su', 'spam4.me', 'spamavert.com',
        'spambob.com', 'spambob.net', 'spambob.org',
        'spambog.com', 'spambog.de', 'spambog.ru',
        'spambox.info', 'spambox.irishspringrealty.com', 'spambox.us',
        'spamcannon.com', 'spamcannon.net', 'spamcero.com',
        'spamcorptastic.com', 'spamcowboy.com', 'spamcowboy.net',
        'spamcowboy.org', 'spamday.com', 'spamex.com',
        'spamfighter.cf', 'spamfighter.ga', 'spamfighter.gq',
        'spamfighter.ml', 'spamfighter.tk', 'spamfree.eu',
        'spamfree24.com', 'spamfree24.de', 'spamfree24.eu',
        'spamfree24.info', 'spamfree24.net', 'spamfree24.org',
        'spamgoes.in', 'spamherelots.com', 'spamhereplease.com',
        'spamhole.com', 'spamify.com', 'spaminator.de',
        'spamkill.info', 'spaml.com', 'spaml.de',
        'spammotel.com', 'spamobox.com', 'spamoff.de',
        'spamslicer.com', 'spamspot.com', 'spamstack.net',
        'spamthis.co.uk', 'spamtrap.ro', 'spamtrail.com',
        'spamwc.de', 'speedgaus.net', 'sry.li',
        'stopmy.spam', 'stuffmail.de', 'supergreatmail.com',
        'supermailer.jp', 'superrito.com', 'superstachel.de',
        'suremail.info', 'svk.jp', 'sweetxxx.de',
        'tafmail.com', 'tagyoureit.com', 'talkinator.com',
        'tapchicuoihoi.com', 'teewars.org', 'teleworm.com',
        'teleworm.us', 'temp.emeraldwebmail.com', 'temp.headstrong.de',
        'tempail.com', 'tempalias.com', 'tempe4mail.com',
        'tempemail.biz', 'tempemail.co.za', 'tempemail.com',
        'tempemail.net', 'tempinbox.co.uk', 'tempinbox.com',
        'tempmail.eu', 'tempmail.it', 'tempmail2.com',
        'tempmaildemo.com', 'tempmailer.com', 'tempmailer.de',
        'tempomail.fr', 'temporaryemail.net', 'temporaryemail.us',
        'temporaryforwarding.com', 'temporaryinbox.com', 'temporarymailaddress.com',
        'thankyou2010.com', 'thankyou2010.com', 'thc.st',
        'thecriminals.com', 'thejoker5.com', 'thisisnotmyrealemail.com',
        'thismail.net', 'throwam.com', 'throwawayemailaddress.com',
        'tilien.com', 'tittbit.in', 'tmail.ws',
        'tmailinator.com', 'toiea.com', 'toomail.biz',
        'topranklist.de', 'tradermail.info', 'trash-amil.com',
        'trash-mail.at', 'trash-mail.cf', 'trash-mail.com',
        'trash-mail.de', 'trash-mail.ga', 'trash-mail.gq',
        'trash-mail.ml', 'trash-mail.tk', 'trash2009.com',
        'trash2010.com', 'trash2011.com', 'trashdevil.com',
        'trashdevil.de', 'trashemail.de', 'trashemails.de',
        'trashimail.com', 'trashimail.de', 'trashmail.at',
        'trashmail.de', 'trashmail.io', 'trashmail.org',
        'trashmail.ws', 'trashmailer.com', 'trashymail.com',
        'trashymail.net', 'trbvm.com', 'trbvn.com',
        'trialmail.de', 'trickmail.net', 'trillianpro.com',
        'tryalert.com', 'turual.com', 'twinmail.de',
        'tyldd.com', 'uggsrock.com', 'umail.net',
        'unmail.ru', 'upliftnow.com', 'uplipht.com',
        'venompen.com', 'veryreallymymail.com', 'vidchart.com',
        'viditag.com', 'viewcastmedia.com', 'viewcastmedia.net',
        'viewcastmedia.org', 'vomoto.com', 'vpn.st',
        'vsimcard.com', 'vubby.com', 'wasteland.rfc822.org',
        'webemail.me', 'webm4il.info', 'weg-werf-email.de',
        'wegwerf-email-addressen.de', 'wegwerf-emails.de',
        'wegwerfadresse.de', 'wegwerfemail.com', 'wegwerfemail.de',
        'wegwerfmail.de', 'wegwerfmail.info', 'wegwerfmail.net',
        'wegwerfmail.org', 'wh4f.org', 'whatiaas.com',
        'whatpaas.com', 'whyspam.me', 'wickmail.net',
        'wilemail.com', 'willhackforfood.biz', 'willselfdestruct.com',
        'winemaven.info', 'wronghead.com', 'wuzup.net',
        'wuzupmail.net', 'wwwnew.eu', 'xagloo.com',
        'xemaps.com', 'xents.com', 'xjoi.com',
        'xmaily.com', 'xoxy.net', 'xyzfree.net',
        'yapped.net', 'yeah.net', 'yep.it',
        'yogamaven.com', 'yomail.info', 'yuurok.com',
        'zehnminutenmail.de', 'zippymail.info', 'zoaxe.com',
        'zoemail.org', 'zomg.info',
    }

    # Suspicious domain patterns (regex-based)
    SUSPICIOUS_PATTERNS = [
        r'^temp.*mail',
        r'^mail.*temp',
        r'^trash.*mail',
        r'^mail.*trash',
        r'^disposable',
        r'^throw.*away',
        r'^fake.*mail',
        r'^spam.*',
        r'^junk.*mail',
        r'^burner',
        r'.*minutemail.*',
        r'.*guerrilla.*',
        r'^anon.*mail',
        r'^no.*reply.*mail',
    ]

    try:
        domain = email.split('@')[1].lower()
    except IndexError:
        raise ValidationError('Invalid email format')

    # Check exact domain match
    if domain in DISPOSABLE_DOMAINS:
        raise ValidationError(
            'Disposable email addresses are not allowed. '
            'Please use a permanent email address.'
        )

    # Check suspicious domain patterns
    domain_name = domain.split('.')[0]
    for pattern in SUSPICIOUS_PATTERNS:
        if re.match(pattern, domain_name):
            raise ValidationError(
                'This email domain appears to be a temporary email service. '
                'Please use a permanent email address.'
            )

    return email


def validate_professional_email(email):
    """
    Validate that email is from a professional/organizational domain.
    Blocks consumer email providers (gmail, yahoo, outlook, hotmail, etc.)
    """
    if not email:
        raise ValidationError('Email cannot be empty')

    # List of blocked consumer email domains
    BLOCKED_DOMAINS = [
        'gmail.com', 'googlemail.com',
        'yahoo.com', 'yahoo.co.uk', 'yahoo.fr', 'yahoo.de', 'yahoo.ca', 'yahoo.in',
        'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
        'aol.com',
        'icloud.com', 'me.com', 'mac.com',
        'protonmail.com', 'proton.me',
        'mail.com',
        'zoho.com',
        'yandex.com', 'yandex.ru',
        'gmx.com', 'gmx.de',
        'mail.ru',
        'qq.com',
        '163.com',
        '126.com',
    ]

    # Extract domain from email
    try:
        domain = email.split('@')[1].lower()
    except IndexError:
        raise ValidationError('Invalid email format')

    # Check if domain is blocked
    if domain in BLOCKED_DOMAINS:
        raise ValidationError(
            f'Please use a professional/organizational email address. '
            f'Consumer email providers like {domain} are not accepted for verification.'
        )

    return email


def validate_social_media_url(platform, url):
    """
    Validate social media URL format for badge verification.
    Returns the URL if valid, raises ValidationError if not.
    """
    if not url:
        return url  # Allow blank

    PLATFORM_PATTERNS = {
        'twitter': r'^https?://(www\.)?(twitter\.com|x\.com)/[A-Za-z0-9_]{1,15}/?$',
        'facebook': r'^https?://(www\.|m\.)?facebook\.com/[A-Za-z0-9_.]+/?$',
        'linkedin': r'^https?://(www\.)?linkedin\.com/in/[A-Za-z0-9_-]+/?$',
        'instagram': r'^https?://(www\.)?instagram\.com/[A-Za-z0-9_.]+/?$',
        'tiktok': r'^https?://(www\.)?tiktok\.com/@[A-Za-z0-9_.]+/?$',
        'youtube': r'^https?://(www\.)?(youtube\.com/(c/|channel/|@)?[A-Za-z0-9_-]+|youtu\.be/[A-Za-z0-9_-]+)/?$',
    }

    pattern = PLATFORM_PATTERNS.get(platform)
    if pattern and not re.match(pattern, url):
        raise ValidationError(
            f'Invalid {platform} URL format. Please provide a valid {platform} profile URL.'
        )

    return url
