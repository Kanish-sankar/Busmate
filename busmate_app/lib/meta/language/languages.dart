import 'package:get/get.dart';

class Languages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          // Splash screen
          'hello': 'Hello',
          'appName': 'BusMate',
          'tagLine': '"WE TRACK, YOU RELAX"',

          // Sign up screen
          'welcomemsg': 'Welcome Aboard!',
          'remeber': 'Remember Me',
          'forgotpass': 'Forgot Password?',
          'idmsg': 'Enter Your ID',
          'passmsg': 'Enter Your Password',
          'login': 'Login',
          'termcondition1': 'By Logging in, you agree to our ',
          'termcondition2': 'Terms & Privacy Policy',
          'helpsupport': 'Need Help? Contact Support',
          'copyright': 'Jupenta © 2024. All rights reserved.',

          // Validation
          'userVal1': 'User Id is required',
          'passVal1': 'Password is required',
          'passVal2': 'Password must be at least 8 characters long',
          'passVal3': 'Password must contain at least one uppercase letter',
          'passVal4': 'Password must contain at least one lowercase letter',
          'passVal5': 'Password must contain at least one number',

          // Stops location screen
          'verifystlocation': 'Verify Your Stop Location',
          'selectlocation': 'Your Stopping Location:',
          'confirm': 'Confirm',

          // Set notification screen
          'selectnotify1': 'Select When Should You Be Notified?',
          'selectnotify2': 'Any One',
          'selectnotifytime': 'Based on a Time Before Your Stop',
          'or': '(or)',

          //dashboard

          //bottombar label
          'home': 'Home',
          'live': 'Live',
          'managing': 'Managing',
          'f&q': 'F&Q',

          //home
          'goodmorning': 'Good Morning!',
          'goodafternoon': 'Good Afternoon!',
          'goodevening': 'Good Evening!',
          'stdname': 'Student Name',
          'stdid': 'Student ID',
          'stdclass': 'Student Class',
          'stdschool': 'Student School',
          'schname': 'School Name',
          'busno': 'Bus No',
          'stdloc': 'Student Location',

          //live
          'livetrack': 'Live Tracking',
          'active': 'Active',
          'inactive': 'Inactive',
          'businfo': 'Bus Information',
          'number': 'Number',
          'route': 'Route',
          'driverinfo': 'Driver Information',
          'name': 'Name',

          //managing
          'mngdetail': 'Manage Your Details',
          'stplocation': 'Your Stop Location',
          'stplocationpref': 'Stoping Location',
          'notfsetting': 'Your Notification Settings',
          'notfpref': 'Notification Preference',
          'notificationType': 'Your Notification Type',
          'notType': 'Notification Type',
          'langsetting': 'Language Settings',
          'currlang': 'Current Language',
          'kidmanage': 'Kids Management',
          'add': 'Add',
          'remove': 'Remove',

          //f&Q
          'helpsupp': 'Help & Support',
          'frqaskque': 'Frequently Asked!',
          'aboutcomp': 'About The Company',
          'comprule1': "- We provide a user-friendly mobile app that connects parents with trusted and qualified child care providers in their area. "
              "Whether you're looking for a nearby daycare, a babysitter for an evening out. or a long-term nanny, "
              "our platform is designed to help you find the perfect match based on your child's needs, preferences, and your schedule.\n "
              "- We are committed to ensuring that every caregiver on our platform meets the highest standards of safety, reliability, "
              "and professionalism. Our app allows parents to review profiles, communicate directly with providers, and book care with ease. ",
          'ourcoreval': 'Our Core Value Are:',
          'compkeyval': "   • Safety: We prioritize the safety of children by ensuring every caregiver undergoes thorough background checks. \n"
              "   • Trust: We are dedicated to providing peace of mind by fostering transparent relationships between parents and caregivers. \n"
              "   • Quality: We connect parents with experienced, skilled, and passionate caregivers who meet each family's unique needs. \n"
              "- Feel free to tweak this according to your company's specific approach, mission, and services!",
          'startconv': 'Start a Convertion...',
          'consupp': 'Contact & Support',
        },
        'hi_IN': {
          'hello': 'नमस्ते',
          'appName': 'बसमेट',
          'tagLine': '"हम ट्रैक करते हैं, आप आराम करें"',
          'welcomemsg': 'आपका स्वागत है!',
          'remeber': 'मुझे याद रखें',
          'forgotpass': 'पासवर्ड भूल गए?',
          'idmsg': 'अपनी आईडी दर्ज करें',
          'passmsg': 'अपना पासवर्ड दर्ज करें',
          'login': 'लॉग इन करें',
          'termcondition1': 'लॉग इन करके, आप हमारी ',
          'termcondition2': 'शर्तों और गोपनीयता नीति से सहमत हैं',
          'helpsupport': 'मदद चाहिए? सहायता केंद्र से संपर्क करें',
          'copyright': 'जुपेंटा © 2024. सर्वाधिकार सुरक्षित।',
          // Validation
          'userVal1': 'यूजर आईडी आवश्यक है',
          'passVal1': 'पासवर्ड आवश्यक है',
          'passVal2': 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए',
          'passVal3': 'पासवर्ड में कम से कम एक बड़ा अक्षर होना चाहिए',
          'passVal4': 'पासवर्ड में कम से कम एक छोटा अक्षर होना चाहिए',
          'passVal5': 'पासवर्ड में कम से कम एक संख्या होनी चाहिए',

// Stops location screen
          'verifystlocation': 'अपने स्टॉप स्थान की पुष्टि करें',
          'selectlocation': 'आपका स्टॉपिंग स्थान:',
          'confirm': 'पुष्टि करें',

// Set notification screen
          'selectnotify1': 'आपको कब सूचित किया जाना चाहिए?',
          'selectnotify2': 'कोई भी एक',
          'selectnotifytime': 'अपने स्टॉप से पहले एक समय के आधार पर',
          'or': '(या)',

// dashboard

// bottombar label
          'home': 'होम',
          'live': 'लाइव',
          'managing': 'प्रबंधन',
          'f&q': 'सामान्य प्रश्न',

// home
          'goodmorning': 'सुप्रभात!',
          'stdname': 'छात्र का नाम',
          'stdid': 'छात्र आईडी',
          'stdclass': 'छात्र कक्षा',
          'stdschool': 'छात्र स्कूल',
          'schname': 'स्कूल का नाम',
          'busno': 'बस नंबर',
          'stdloc': 'छात्र स्थान',

// live
          'livetrack': 'लाइव ट्रैकिंग',
          'active': 'सक्रिय',
          'inactive': 'निष्क्रिय',
          'businfo': 'बस जानकारी',
          'number': 'संख्या',
          'route': 'रूट',
          'driverinfo': 'ड्राइवर जानकारी',
          'name': 'नाम',

// managing
          'mngdetail': 'अपने विवरण प्रबंधित करें',
          'stplocation': 'आपका स्टॉप स्थान',
          'notfsetting': 'सूचना सेटिंग',
          'notificationType': 'आपकी सूचना सेटिंग',
          'langsetting': 'भाषा सेटिंग',
          'currlang': 'वर्तमान भाषा',
          'kidmanage': 'बच्चों का प्रबंधन',
          'add': 'जोड़ें',
          'remove': 'हटाएं',

// f&Q
          'helpsupp': 'सहायता और समर्थन',
          'frqaskque': 'अक्सर पूछे जाने वाले प्रश्न!',
          'aboutcomp': 'कंपनी के बारे में',
          'comprule1': "- हम एक उपयोगकर्ता के अनुकूल मोबाइल ऐप प्रदान करते हैं जो माता-पिता को उनके क्षेत्र में विश्वसनीय और योग्य बाल देखभाल प्रदाताओं से जोड़ता है। "
              "चाहे आप पास के डेकेयर की तलाश कर रहे हों, एक शाम के लिए बेबीसिटर चाहिए हो, या दीर्घकालिक नानी की आवश्यकता हो, "
              "हमारा प्लेटफॉर्म आपके बच्चे की जरूरतों, प्राथमिकताओं और आपकी समय-सारिणी के आधार पर सही मेल खोजने में मदद करता है।\n "
              "- हम यह सुनिश्चित करने के लिए प्रतिबद्ध हैं कि हमारे प्लेटफॉर्म पर हर देखभालकर्ता उच्चतम सुरक्षा, विश्वसनीयता, "
              "और पेशेवर मानकों को पूरा करता हो। हमारा ऐप माता-पिता को प्रोफाइल की समीक्षा करने, प्रदाताओं से सीधे संवाद करने और आसानी से देखभाल बुक करने की अनुमति देता है।",

          'ourcoreval': 'हमारे मुख्य मूल्य हैं:',
          'compkeyval': "   • सुरक्षा: हम बच्चों की सुरक्षा को प्राथमिकता देते हैं और यह सुनिश्चित करते हैं कि हर देखभालकर्ता की पूरी पृष्ठभूमि जांच की जाए। \n"
              "   • विश्वास: हम माता-पिता और देखभालकर्ताओं के बीच पारदर्शी संबंधों को बढ़ावा देकर मानसिक शांति प्रदान करने के लिए समर्पित हैं। \n"
              "   • गुणवत्ता: हम माता-पिता को अनुभवी, कुशल और जुनूनी देखभालकर्ताओं से जोड़ते हैं जो प्रत्येक परिवार की अनूठी जरूरतों को पूरा करते हैं। \n"
              "- इसको आपकी कंपनी के विशेष दृष्टिकोण, मिशन और सेवाओं के अनुसार संशोधित किया जा सकता है!",

          'startconv': 'एक बातचीत शुरू करें...',
          'consupp': 'संपर्क और समर्थन',
        },
        'ta_IN': {
          // Splash screen
          'hello': 'ஹலோ',
          'appName': 'பஸ் மேட்',
          'tagLine': '"நாங்கள் கண்காணிக்கிறோம், நீங்கள் ஓய்வெடுங்கள்"',

          // Sign up screen
          'welcomemsg': 'கப்பலேற வரவேற்கிறோம்!',
          'remeber': 'என்னை நினைவில் கொள்',
          'forgotpass': 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
          'idmsg': 'உங்கள் ஐடியை உள்ளிடவும்',
          'passmsg': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
          'login': 'உள்நுழைய',
          'termcondition1': 'உள்நுழைவதன் மூலம், நீங்கள் எங்கள் ',
          'termcondition2':
              'விதிமுறைகள் & தனியுரிமைக் கொள்கை ஒப்புக்கொள்கிறீர்கள்',
          'helpsupport': 'உதவி தேவையா? ஆதரவுடன் தொடர்புகொள்ளவும்',
          'copyright':
              'ஜுபென்டா © 2024. அனைத்து உரிமைகளும் பாதுகாக்கப்பட்டுள்ளன.',

          // Validation
          'userVal1': 'பயனர் ஐடி தேவை',
          'passVal1': 'கடவுச்சொல் தேவை',
          'passVal2':
              'கடவுச்சொல் குறைந்தது 8 எழுத்துகள் நீளமாக இருக்க வேண்டும்',
          'passVal3':
              'கடவுச்சொல்லில் குறைந்தது ஒரு பெரிய எழுத்து இருக்க வேண்டும்',
          'passVal4':
              'கடவுச்சொல்லில் குறைந்தது ஒரு சிறிய எழுத்து இருக்க வேண்டும்',
          'passVal5': 'கடவுச்சொல்லில் குறைந்தது ஒரு எண் இருக்க வேண்டும்',

          // Stops location screen
          'verifystlocation':
              'உங்கள் நிறுத்தத்தின் இருப்பிடத்தை சரிபார்க்கவும்',
          'selectlocation': 'உங்கள் நிறுத்த இருப்பிடம்:',
          'confirm': 'உறுதிப்படுத்தவும்',

          // Set notification screen
          'selectnotify1':
              'நீங்கள் எப்போது அறிவிக்கப்பட வேண்டும் என்பதை தேர்ந்தெடுக்கவும்?',
          'selectnotify2': 'ஏதேனும் ஒன்று',
          'selectnotifytime':
              'உங்கள் நிறுத்தத்திற்கு முன் ஒரு குறிப்பிட்ட நேரத்தில்',
          'or': '(அல்லது)',

          // Dashboard

          // Bottom bar label
          'home': 'முகப்பு',
          'live': 'நேரடி',
          'managing': 'நிர்வகிப்பு',
          'f&q': 'கேள்விகள் & பதில்கள்',

          // Home
          'goodmorning': 'காலை வணக்கம்!',
          'stdname': 'மாணவர் பெயர்',
          'stdid': 'மாணவர் ஐடி',
          'stdclass': 'மாணவர் வகுப்பு',
          'stdschool': 'மாணவர் பள்ளி',
          'schname': 'பள்ளியின் பெயர்',
          'busno': 'பேருந்து எண்',
          'stdloc': 'மாணவர் இருப்பிடம்',

          // Live
          'livetrack': 'நேரடி கண்காணிப்பு',
          'active': 'செயலில் உள்ளது',
          'inactive': 'செயலற்றது',
          'businfo': 'பேருந்து தகவல்',
          'number': 'எண்',
          'route': 'திசை',
          'driverinfo': 'ஓட்டுநர் தகவல்',
          'name': 'பெயர்',

          // Managing
          'mngdetail': 'உங்கள் விவரங்களை நிர்வகிக்கவும்',
          'stplocation': 'உங்கள் நிறுத்த இருப்பிடம்',
          'notfsetting': 'அறிவிப்பு அமைப்புகள்',
          'notificationType': 'உங்கள் அறிவிப்பு வகை',
          'langsetting': 'மொழி அமைப்புகள்',
          'currlang': 'தற்போதைய மொழி',
          'kidmanage': 'குழந்தைகளை நிர்வகிக்கவும்',
          'add': 'சேர்க்க',
          'remove': 'நீக்க',

          // F&Q
          'helpsupp': 'உதவி & ஆதரவு',
          'frqaskque': 'அடிக்கடி கேட்கப்படும் கேள்விகள்!',
          'aboutcomp': 'நிறுவனம் பற்றி',
          'comprule1': "- நாங்கள் பெற்றோர்களை அவர்களின் பகுதியில் நம்பிக்கையான குழந்தை பராமரிப்பாளர்களுடன் இணைக்கும் பயனர் நட்பு மொபைல் செயலியை வழங்குகிறோம். "
              "நீங்கள் அருகிலுள்ள ஒரு குழந்தை பராமரிப்பு மையத்தையா அல்லது ஒரு நாள் குழந்தைப் பார்வையாளரையா தேடினாலும், "
              "எங்கள் தளம் உங்கள் குழந்தையின் தேவைகளுக்கு ஏற்ப சரியான பார்வையாளரைத் தேர்ந்தெடுக்க உதவுகிறது.\n"
              "- எங்கள் தளத்தில் உள்ள அனைத்து பராமரிப்பாளர்களும் பாதுகாப்பு, நம்பகத்தன்மை மற்றும் தொழில்முறைத் தரங்களை பூர்த்தி செய்ய உறுதிபூண்டுள்ளோம். "
              "பெற்றோர்கள் எங்கள் செயலியில் பார்வையாளர் சுயவிவரங்களை மதிப்பீடு செய்யலாம், நேரடியாக தொடர்பு கொள்ளலாம் மற்றும் தேவையான பராமரிப்பை முன்பதிவு செய்யலாம்.",
          'ourcoreval': 'எங்கள் மூல காரணிகள்:',
          'compkeyval': "   • பாதுகாப்பு: எங்கள் தளத்தில் உள்ள அனைத்து பராமரிப்பாளர்களும் முழுமையான பின்னணி சரிபார்ப்பு செய்யப்படுவார்கள். \n"
              "   • நம்பிக்கை: பெற்றோர்களுக்கும் பராமரிப்பாளர்களுக்கும் வெளிப்படையான உறவுகளை வழங்குவதே எங்கள் நோக்கம். \n"
              "   • தரம்: பெற்றோர்களை அனுபவமுள்ள மற்றும் திறமையான பராமரிப்பாளர்களுடன் இணைக்கிறோம். \n"
              "- உங்கள் நிறுவனத்தின் நோக்கம் மற்றும் சேவைகளை பொருத்த வகையில் இதை மாற்றிக் கொள்ளலாம்!",
          'startconv': 'உரையாடலை தொடங்கவும்...',
          'consupp': 'தொடர்பு & ஆதரவு'
        },
        'kn_IN': {
          // Splash screen
          'hello': 'ಹಲೋ',
          'appName': 'ಬಸ್ ಮೆಟ್',
          'tagLine': '"ನಾವು ಟ್ರ್ಯಾಕ್ ಮಾಡುತ್ತೇವೆ, ನೀವು ಆರಾಮಾಗಿರಬಹುದು"',

          // Sign up screen
          'welcomemsg': 'ಸ್ವಾಗತ!',
          'remeber': 'ನನ್ನನ್ನು ನೆನಪಿನಲ್ಲಿ ಇಡು',
          'forgotpass': 'ಪಾಸ್ವರ್ಡ್ ಮರೆತಿರುವಿರಾ?',
          'idmsg': 'ನಿಮ್ಮ ಐಡಿಯನ್ನು ನಮೂದಿಸಿ',
          'passmsg': 'ನಿಮ್ಮ ಪಾಸ್ವರ್ಡ್ ನಮೂದಿಸಿ',
          'login': 'ಲಾಗಿನ್',
          'termcondition1': 'ಲಾಗಿನ್ ಮಾಡುವ ಮೂಲಕ, ನೀವು ನಮ್ಮ ',
          'termcondition2': 'ನಿಯಮಗಳು & ಗೌಪ್ಯತಾ ನೀತಿಗೆ ಒಪ್ಪಿಕೊಂಡಿದ್ದಾರೆ',
          'helpsupport': 'ಸಹಾಯ ಬೇಕಾ? ಸಹಾಯ ಕೇಂದ್ರವನ್ನು ಸಂಪರ್ಕಿಸಿ',
          'copyright': 'ಜುಪೆಂಟಾ © 2024. ಎಲ್ಲಾ ಹಕ್ಕುಗಳನ್ನು ಕಾಯ್ದಿರಿಸಲಾಗಿದೆ.',

          // Validation
          'userVal1': 'ಬಳಕೆದಾರ ಐಡಿ ಅಗತ್ಯವಿದೆ',
          'passVal1': 'ಪಾಸ್ವರ್ಡ್ ಅಗತ್ಯವಿದೆ',
          'passVal2': 'ಪಾಸ್ವರ್ಡ್ ಕನಿಷ್ಟ 8 ಅಕ್ಷರಗಳ ಇರಬೇಕು',
          'passVal3': 'ಪಾಸ್ವರ್ಡ್ ಕನಿಷ್ಟ ಒಂದು ದೊಡ್ಡ ಅಕ್ಷರವನ್ನು ಒಳಗೊಂಡಿರಬೇಕು',
          'passVal4': 'ಪಾಸ್ವರ್ಡ್ ಕನಿಷ್ಟ ಒಂದು ಚಿಕ್ಕ ಅಕ್ಷರವನ್ನು ಒಳಗೊಂಡಿರಬೇಕು',
          'passVal5': 'ಪಾಸ್ವರ್ಡ್ ಕನಿಷ್ಟ ಒಂದು ಸಂಖ್ಯೆ ಇರಬೇಕು',

          // Stops location screen
          'verifystlocation': 'ನಿಮ್ಮ ನಿಲುಗಡೆ ಸ್ಥಳವನ್ನು ಪರಿಶೀಲಿಸಿ',
          'selectlocation': 'ನಿಮ್ಮ ನಿಲುಗಡೆ ಸ್ಥಳ:',
          'confirm': 'ದೃಢೀಕರಿಸಿ',

          // Set notification screen
          'selectnotify1':
              'ನಿಮ್ಮ ನಿಲುಗಡೆಯ ಮುಂಚಿನ ಸಮಯದಲ್ಲಿ ಎಚ್ಚರಿಸಲು ಆಯ್ಕೆಮಾಡಿ?',
          'selectnotify2': 'ಯಾವುದೇ ಒಂದು',
          'selectnotifytime': 'ನಿಮ್ಮ ನಿಲುಗಡೆಯ ಮುಂಚಿನ ನಿರ್ದಿಷ್ಟ ಸಮಯದಲ್ಲಿ',
          'or': '(ಅಥವಾ)',

          // Dashboard

          // Bottom bar label
          'home': 'ಮುಖಪುಟ',
          'live': 'ತಂಡದ ವರದಿ',
          'managing': 'ನಿರ್ವಹಣೆ',
          'f&q': 'FAQ',

          // Home
          'goodmorning': 'ಶುಭೋದಯ!',
          'stdname': 'ವಿದ್ಯಾರ್ಥಿಯ ಹೆಸರು',
          'stdid': 'ವಿದ್ಯಾರ್ಥಿ ಐಡಿ',
          'stdclass': 'ವಿದ್ಯಾರ್ಥಿ ವರ್ಗ',
          'stdschool': 'ವಿದ್ಯಾರ್ಥಿ ಶಾಲೆ',
          'schname': 'ಶಾಲೆಯ ಹೆಸರು',
          'busno': 'ಬಸ್ ಸಂಖ್ಯೆ',
          'stdloc': 'ವಿದ್ಯಾರ್ಥಿ ಸ್ಥಳ',

          // Live
          'livetrack': 'ಲೈವ್ ಟ್ರಾಕಿಂಗ್',
          'active': 'ಸಕ್ರಿಯ',
          'inactive': 'ನಿಷ್ಕ್ರಿಯ',
          'businfo': 'ಬಸ್ ಮಾಹಿತಿ',
          'number': 'ಸಂಖ್ಯೆ',
          'route': 'ಮಾರ್ಗ',
          'driverinfo': 'ಚಾಲಕ ಮಾಹಿತಿ',
          'name': 'ಹೆಸರು',

          // Managing
          'mngdetail': 'ನಿಮ್ಮ ವಿವರಗಳನ್ನು ನಿರ್ವಹಿಸಿ',
          'stplocation': 'ನಿಮ್ಮ ನಿಲುಗಡೆ ಸ್ಥಳ',
          'notfsetting': 'ಅಧಿಸೂಚನೆ ಸೆಟ್ಟಿಂಗ್ಗಳು',
          'notificationType': 'ನಿಮ್ಮ ಅಧಿಸೂಚನೆ ಪ್ರಕಾರ',
          'langsetting': 'ಭಾಷಾ ಸೆಟ್ಟಿಂಗ್ಗಳು',
          'currlang': 'ಪ್ರಸ್ತುತ ಭಾಷೆ',
          'kidmanage': 'ಮಕ್ಕಳ ನಿರ್ವಹಣೆ',
          'add': 'ಸೇರಿಸಿ',
          'remove': 'ತೆಗೆದುಹಾಕಿ',

          // F&Q
          'helpsupp': 'ಸಹಾಯ & ಬೆಂಬಲ',
          'frqaskque': 'ಪದೇ ಪದೇ ಕೇಳುವ ಪ್ರಶ್ನೆಗಳು!',
          'aboutcomp': 'ಕಂಪನಿಯ ಬಗ್ಗೆ',
          'comprule1': "- ನಾವು ಬಳಕೆದಾರ ಸ್ನೇಹಿ ಮೊಬೈಲ್ ಅಪ್ಲಿಕೇಶನ್ ಅನ್ನು ಒದಗಿಸುತ್ತೇವೆ, "
              "ಅದು ಪೋಷಕರನ್ನು ಅವರ ಪ್ರದೇಶದ ನಂಬಲರ್ಹ ಮಕ್ಕಳ ಆರೈಕೆದಾರರೊಂದಿಗೆ ಸಂಪರ್ಕಗೊಳಿಸುತ್ತದೆ. "
              "ನೀವು ಹತ್ತಿರದ ಡೇಕೆರ್ನ್ನು ಅಥವಾ ಕೇವಲ ಒಂದು ಸಂಜೆ ನೋಡಿಕೊಳ್ಳುವ ವ್ಯಕ್ತಿಯನ್ನೇ ಹುಡುಕುತ್ತಿದ್ದರೂ, "
              "ನಮ್ಮ ವೇದಿಕೆ ನಿಮ್ಮ ಮಕ್ಕಳ ಅಗತ್ಯಗಳಿಗೆ ಅನುಗುಣವಾಗಿ ಅತ್ಯುತ್ತಮ ಆರೈಕೆಗಾರರನ್ನು ಹುಡುಕಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ.\n"
              "- ನಮ್ಮ ವೇದಿಕೆಯಲ್ಲಿ ಇರುವ ಪ್ರತಿಯೊಬ್ಬ ಆರೈಕೆದಾರನೂ ಸುರಕ್ಷತೆ, ವಿಶ್ವಾಸಾರ್ಹತೆ, "
              "ಮತ್ತು ವೃತ್ತಿಪರತೆಯ ಅತ್ಯುತ್ತಮ ಮಾನದಂಡಗಳನ್ನು ಪೂರೈಸುತ್ತಾನೆ. "
              "ಪೋಷಕರು ನಮ್ಮ ಅಪ್ಲಿಕೇಶನ್ನಲ್ಲಿ ಆರೈಕೆದಾರರ ಪ್ರೊಫೈಲ್ಗಳನ್ನು ಪರಿಶೀಲಿಸಬಹುದು, "
              "ನೇರವಾಗಿ ಸಂಪರ್ಕಿಸಬಹುದು ಮತ್ತು ಆರೈಕೆಯನ್ನು ಸುಲಭವಾಗಿ ಕಾಯ್ದಿರಿಸಬಹುದು.",
          'ourcoreval': 'ನಮ್ಮ ಮೂಲ ಮೌಲ್ಯಗಳು:',
          'compkeyval': "   • ಸುರಕ್ಷತೆ: ನಮ್ಮ ವೇದಿಕೆಯಲ್ಲಿರುವ ಪ್ರತಿಯೊಬ್ಬ ಆರೈಕೆದಾರನಿಗೂ ಸೂಕ್ಷ್ಮ ಹಿನ್ನೆಲೆ ಪರಿಶೀಲನೆ ಮಾಡಲಾಗುತ್ತದೆ. \n"
              "   • ನಂಬಿಕೆ: ಪೋಷಕರು ಮತ್ತು ಆರೈಕೆದಾರರ ನಡುವೆ ನಂಬಿಕೆಯನ್ನು ಬೆಳೆಸುವಲ್ಲಿ ನಾವು ಸಮರ್ಪಿತರಾಗಿದ್ದೇವೆ. \n"
              "   • ಗುಣಮಟ್ಟ: ಪೋಷಕರನ್ನು ಅನುಭವೀ ಮತ್ತು ನುರಿತ ಆರೈಕೆದಾರರೊಂದಿಗೆ ಸಂಪರ್ಕಗೊಳಿಸುತ್ತೇವೆ. \n"
              "- ನಿಮ್ಮ ಕಂಪನಿಯ ದೃಷ್ಟಿಕೋನ, ಉದ್ದೇಶ, ಸೇವೆಗಳನ್ನು ಆಧರಿಸಿ ಇದನ್ನು ಹೊಂದಿಸಬಹುದು!",
          'startconv': 'ಸಂವಾದ ಪ್ರಾರಂಭಿಸಿ...',
          'consupp': 'ಸಂಪರ್ಕ & ಬೆಂಬಲ'
        },
        'te_IN': {
          // Splash screen
          'hello': 'హలో',
          'appName': 'బస్ మేట్',
          'tagLine': '"మేము ట్రాక్ చేస్తాం, మీరు విశ్రాంతి తీసుకోండి"',

          // Sign up screen
          'welcomemsg': 'స్వాగతం!',
          'remeber': 'నన్ను గుర్తుంచుకో',
          'forgotpass': 'పాస్వర్డ్ మర్చిపోయారా?',
          'idmsg': 'మీ ఐడీను నమోదు చేయండి',
          'passmsg': 'మీ పాస్వర్డ్ను నమోదు చేయండి',
          'login': 'లాగిన్',
          'termcondition1': 'లాగిన్ చేయడం ద్వారా, మీరు మా ',
          'termcondition2': 'నియమాలు & గోప్యతా విధానాన్ని అంగీకరిస్తున్నారు',
          'helpsupport': 'సహాయం కావాలా? మద్దతును సంప్రదించండి',
          'copyright': 'జుపెంటా © 2024. అన్ని హక్కులు రిజర్వ్ చేయబడ్డాయి.',

          // Validation
          'userVal1': 'యూజర్ ఐడి అవసరం',
          'passVal1': 'పాస్వర్డ్ అవసరం',
          'passVal2': 'పాస్వర్డ్ కనీసం 8 అక్షరాల పొడవుగా ఉండాలి',
          'passVal3': 'పాస్వర్డ్ కనీసం ఒక పెద్ద అక్షరాన్ని కలిగి ఉండాలి',
          'passVal4': 'పాస్వర్డ్ కనీసం ఒక చిన్న అక్షరాన్ని కలిగి ఉండాలి',
          'passVal5': 'పాస్వర్డ్ కనీసం ఒక నంబర్ కలిగి ఉండాలి',

          // Stops location screen
          'verifystlocation': 'మీ స్టాప్ స్థానాన్ని ధృవీకరించండి',
          'selectlocation': 'మీ స్టాప్ లొకేషన్:',
          'confirm': 'ధృవీకరించండి',

          // Set notification screen
          'selectnotify1': 'మీరు ఎప్పుడూ నోటిఫికేషన్ అందుకోవాలనుకుంటున్నారు?',
          'selectnotify2': 'ఏదైనా ఒకటి',
          'selectnotifytime': 'మీ స్టాప్కు ముందుగా సమయానికి ఆధారంగా',
          'or': '(లేదా)',

          // Dashboard

          // Bottom bar label
          'home': 'హోం',
          'live': 'ప్రత్యక్ష ప్రసారం',
          'managing': 'నిర్వహణ',
          'f&q': 'FAQ',

          // Home
          'goodmorning': 'శుభోదయం!',
          'stdname': 'విద్యార్థి పేరు',
          'stdid': 'విద్యార్థి ఐడి',
          'stdclass': 'విద్యార్థి తరగతి',
          'stdschool': 'విద్యార్థి స్కూల్',
          'schname': 'పాఠశాల పేరు',
          'busno': 'బస్సు సంఖ్య',
          'stdloc': 'విద్యార్థి స్థానం',

          // Live
          'livetrack': 'లైవ్ ట్రాకింగ్',
          'active': 'సక్రియం',
          'inactive': 'నిష్క్రియం',
          'businfo': 'బస్ సమాచారం',
          'number': 'సంఖ్య',
          'route': 'మార్గం',
          'driverinfo': 'డ్రైవర్ సమాచారం',
          'name': 'పేరు',

          // Managing
          'mngdetail': 'మీ వివరాలను నిర్వహించండి',
          'stplocation': 'మీ స్టాప్ లొకేషన్',
          'notfsetting': 'నోటిఫికేషన్ సెట్టింగులు',
          'notificationType': 'మీ నోటిఫికేషన్ రకం',
          'langsetting': 'భాషా సెట్టింగులు',
          'currlang': 'ప్రస్తుత భాష',
          'kidmanage': 'కిడ్స్ మేనేజ్మెంట్',
          'add': 'జోడించండి',
          'remove': 'తొలగించండి',

          // F&Q
          'helpsupp': 'సహాయం & మద్దతు',
          'frqaskque': 'తరచుగా అడిగే ప్రశ్నలు!',
          'aboutcomp': 'కంపెనీ గురించి',
          'comprule1': "- మేము ఒక వినియోగదారు స్నేహపూర్వక మొబైల్ యాప్ను అందిస్తున్నాము, "
              "ఇది తల్లిదండ్రులను వారి ప్రాంతంలోని నమ్మదగిన మరియు అర్హత కలిగిన బాల సంరక్షణ దాతలతో అనుసంధానిస్తుంది. "
              "మీరు సమీపంలోని డేకేర్ను లేదా ఒక సాయంత్రం బేబీ సిట్టింగ్ కోసం వ్యక్తిని వెతుకుతున్నా, "
              "మా ప్లాట్ఫాం మీ పిల్లల అవసరాలు, ప్రాధాన్యతలు మరియు మీ షెడ్యూల్కు అనుగుణంగా సరైన సంరక్షకుడిని కనుగొనడానికి సహాయపడుతుంది.\n"
              "- మా ప్లాట్ఫామ్లోని ప్రతి సంరక్షకుడు భద్రత, నమ్మకత మరియు వృత్తిపరమైన అత్యున్నత ప్రమాణాలను కలిగి ఉంటారని మేము హామీ ఇస్తాము. "
              "తల్లిదండ్రులు మా యాప్ను ఉపయోగించి సంరక్షకుల ప్రొఫైల్లను సమీక్షించవచ్చు, "
              "నేరుగా కమ్యూనికేట్ చేయవచ్చు మరియు సంరక్షణను సులభంగా బుక్ చేసుకోవచ్చు.",
          'ourcoreval': 'మా ప్రాథమిక విలువలు:',
          'compkeyval': "   • భద్రత: మా ప్లాట్ఫామ్లో ప్రతి సంరక్షకుడిపై సమగ్ర బ్యాక్గ్రౌండ్ తనిఖీలు చేస్తాం. \n"
              "   • నమ్మకం: తల్లిదండ్రులు మరియు సంరక్షకుల మధ్య పారదర్శక సంబంధాలను పెంపొందించడానికి కట్టుబడి ఉన్నాము. \n"
              "   • నాణ్యత: తల్లిదండ్రులను అనుభవజ్ఞులైన, నైపుణ్యం కలిగిన మరియు అభిరుచిగల సంరక్షకులతో అనుసంధానిస్తాము. \n"
              "- మీ కంపెనీ యొక్క ప్రత్యేక దృక్కోణం, లక్ష్యం మరియు సేవలకు అనుగుణంగా దీన్ని మార్చుకోవచ్చు!",
          'startconv': 'సంభాషణ ప్రారంభించండి...',
          'consupp': 'సంప్రదింపు & మద్దతు'
        },
        'ml_IN': {
          // Splash screen
          'hello': 'ഹലോ',
          'appName': 'ബസ് മേറ്റ്',
          'tagLine': '"ഞങ്ങൾ ട്രാക്ക് ചെയ്യുന്നു, നിങ്ങൾ വിശ്രമിക്കാം"',

          // Sign up screen
          'welcomemsg': 'സ്വാഗതം!',
          'remeber': 'എന്നെ ഓർമ്മിക്കു',
          'forgotpass': 'പാസ്വേഡ് മറന്നോ?',
          'idmsg': 'നിങ്ങളുടെ ഐഡി നൽകുക',
          'passmsg': 'നിങ്ങളുടെ പാസ്വേഡ് നൽകുക',
          'login': 'ലോഗിൻ',
          'termcondition1': 'ലോഗിൻ ചെയ്യുന്നതോടെ, നിങ്ങൾ ഞങ്ങളുടെ ',
          'termcondition2': 'നിബന്ധനകളും സ്വകാര്യതാ നയവും അംഗീകരിക്കുന്നു',
          'helpsupport': 'സഹായം ആവശ്യമുണ്ടോ? പിന്തുണയെ ബന്ധപ്പെടുക',
          'copyright':
              'ജുപെന്റാ © 2024. എല്ലാ അവകാശങ്ങളും സംരക്ഷിക്കപ്പെട്ടിരിക്കുന്നു.',

          // Validation
          'userVal1': 'ഉപയോക്തൃ ഐഡി ആവശ്യമാണ്',
          'passVal1': 'പാസ്വേഡ് ആവശ്യമാണ്',
          'passVal2': 'പാസ്വേഡ് കുറഞ്ഞത് 8 അക്ഷരങ്ങൾ നീളമുള്ളതായിരിക്കണം',
          'passVal3': 'പാസ്വേഡിൽ കുറഞ്ഞത് ഒരു വലിയ അക്ഷരം ഉണ്ടായിരിക്കണം',
          'passVal4': 'പാസ്വേഡിൽ കുറഞ്ഞത് ഒരു ചെറിയ അക്ഷരം ഉണ്ടായിരിക്കണം',
          'passVal5': 'പാസ്വേഡിൽ കുറഞ്ഞത് ഒരു സംഖ്യ ഉണ്ടായിരിക്കണം',

          // Stops location screen
          'verifystlocation': 'നിങ്ങളുടെ സ്റ്റോപ്പ് ലൊക്കേഷൻ സ്ഥിരീകരിക്കുക',
          'selectlocation': 'നിങ്ങളുടെ സ്റ്റോപ്പ് ലൊക്കേഷൻ:',
          'confirm': 'സ്ഥിരീകരിക്കുക',

          // Set notification screen
          'selectnotify1':
              'നിങ്ങൾക്ക് അറിയിപ്പ് ലഭിക്കേണ്ട സമയത്തെ തിരഞ്ഞെടുക്കുക?',
          'selectnotify2': 'ഏതെങ്കിലും ഒന്ന്',
          'selectnotifytime':
              'നിങ്ങളുടെ സ്റ്റോപ്പിന് മുമ്പ് ഒരു സമയത്തിന് അടിസ്ഥാനമാക്കി',
          'or': '(അല്ലെങ്കിൽ)',

          // Dashboard

          // Bottom bar label
          'home': 'ഹോം',
          'live': 'ലൈവ്',
          'managing': 'മാനേജിംഗ്',
          'f&q': 'F&Q',

          // Home
          'goodmorning': 'ഗുഡ് മോണിംഗ്!',
          'stdname': 'വിദ്യാർത്ഥിയുടെ പേര്',
          'stdid': 'വിദ്യാർത്ഥി ഐഡി',
          'stdclass': 'വിദ്യാർത്ഥിയുടെ ക്ലാസ്',
          'stdschool': 'വിദ്യാർത്ഥിയുടെ സ്കൂൾ',
          'schname': 'സ്കൂളിന്റെ പേര്',
          'busno': 'ബസ് നമ്പർ',
          'stdloc': 'വിദ്യാർത്ഥിയുടെ ലൊക്കേഷൻ',

          // Live
          'livetrack': 'ലൈവ് ട്രാക്കിംഗ്',
          'active': 'സജീവം',
          'inactive': 'നിഷ്ക്രിയം',
          'businfo': 'ബസ് വിവരങ്ങൾ',
          'number': 'നമ്പർ',
          'route': 'റൂട്ട്',
          'driverinfo': 'ഡ്രൈവർ വിവരം',
          'name': 'പേര്',

          // Managing
          'mngdetail': 'നിങ്ങളുടെ വിശദാംശങ്ങൾ നിയന്ത്രിക്കുക',
          'stplocation': 'നിങ്ങളുടെ സ്റ്റോപ്പ് ലൊക്കേഷൻ',
          'notfsetting': 'അറിയിപ്പ് ക്രമീകരണങ്ങൾ',
          'notificationType': 'നിങ്ങളുടെ അറിയിപ്പ് തരം',
          'langsetting': 'ഭാഷാ ക്രമീകരണങ്ങൾ',
          'currlang': 'നിലവിലുള്ള ഭാഷ',
          'kidmanage': 'കുട്ടികളുടെ മാനേജ്മെന്റ്',
          'add': 'ചേർക്കുക',
          'remove': 'നീക്കം ചെയ്യുക',

          // F&Q
          'helpsupp': 'സഹായം & പിന്തുണ',
          'frqaskque': 'പതിവായി ചോദിക്കുന്നവ!',
          'aboutcomp': 'കമ്പനി പരിചയം',
          'comprule1': "- ഞങ്ങൾ ഒരു ഉപയോക്തൃ സൗഹൃദ മൊബൈൽ ആപ്പ് നൽകുന്നു, "
              "അത് രക്ഷിതാക്കളെയും വിശ്വസനീയരായ ബാല പരിചരണ ദാതാക്കളെയും ബന്ധിപ്പിക്കുന്നു. "
              "നിങ്ങൾ അടുത്തുള്ള ഡേകെയറോ അല്ലെങ്കിൽ ഒരു വൈകീട്ട് കുട്ടികളെ പരിചരിക്കാനുള്ള ആളോ "
              "തേടുകയാണെങ്കിൽ, ഞങ്ങളുടെ പ്ലാറ്റ്ഫോം നിങ്ങളുടെ ആവശ്യങ്ങൾക്കനുസരിച്ച് മികച്ച Babysitter കണ്ടെത്താൻ സഹായിക്കും.\n"
              "- ഞങ്ങളുടെ പ്ലാറ്റ്ഫോമിലെ എല്ലാ പരിചരണദാതാക്കളും സുരക്ഷ, വിശ്വാസ്യത, "
              "ഒപ്പം പ്രൊഫഷണലിസം എന്നിവയിൽ ഉന്നത നിലവാരങ്ങൾ പാലിക്കുന്നതായി ഉറപ്പുനൽകുന്നു. "
              "രക്ഷിതാക്കൾക്ക് ഞങ്ങളുടെ ആപ്പ് ഉപയോഗിച്ച് Babysitter പ്രൊഫൈലുകൾ പരിശോധിക്കാനും "
              "നേരിട്ട് ആശയവിനിമയം നടത്താനും ബുക്കിംഗ് നടത്താനും കഴിയും.",
          'ourcoreval': 'ഞങ്ങളുടെ മുഖ്യ മൂല്യങ്ങൾ:',
          'compkeyval': "   • സുരക്ഷ: ഞങ്ങളുടെ പ്ലാറ്റ്ഫോമിലെ ഓരോ പരിചരണദാതാവിനും കൃത്യമായ പശ്ചാത്തല പരിശോധന നടത്തപ്പെടുന്നു. \n"
              "   • വിശ്വാസം: രക്ഷിതാക്കളുടെയും പരിചരണദാതാക്കളുടെയും തമ്മിൽ വിശ്വാസം ഉറപ്പാക്കുന്നു. \n"
              "   • ഗുണമേന്മ: മികച്ച പരിചരണ ദാതാക്കളെ രക്ഷിതാക്കളുമായി ബന്ധിപ്പിക്കുന്നു. \n"
              "- നിങ്ങളുടെ കമ്പനിയുടെ ദിശ, ദൗത്യം, സേവനങ്ങൾ എന്നിവയെ അടിസ്ഥാനമാക്കി ഇതിനെ നിങ്ങളുടെ ആവശ്യമൊത്ത് "
              "മാറ്റിച്ചിട്ടുള്ളത്!",
          'startconv': 'സംവാദം ആരംഭിക്കുക...',
          'consupp': 'ബന്ധപ്പെടുക & പിന്തുണ'
        },
      };
}
