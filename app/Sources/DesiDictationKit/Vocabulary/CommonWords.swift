import Foundation

/// Words the vocabulary corrector must never replace on its own
/// (AUTO_VOCABULARY.md §3.4). Only a pair the user confirmed (a
/// PersonalDictionary entry) may change one of these.
///
/// Hand-curated in-repo: the usual frequency lists (Norvig's count_1w) carry
/// no data licence. Order doesn't matter; whitespace separates words.
public enum CommonWords {
    public static func contains(_ word: String) -> Bool {
        all.contains(word.lowercased())
    }

    /// True for everyday Roman-Hinglish words ("nahi", "kya", "yaar").
    public static func isHinglish(_ word: String) -> Bool {
        hinglish.contains(word.lowercased())
    }

    private static let all: Set<String> = english.union(hinglish)

    private static let english: Set<String> = words("""
    the be to of and a in that have i it for not on with he as you do at this but his by from they we say her she or an
    will my one all would there their what so up out if about who get which go me when make can like time no just him know
    take people into year your good some could them see other than then now look only come its over think also back after
    use two how our work first well way even new want because any these give day most us is are was were been has had did
    does done said made went gone got am being here where why very much many more less few lot lots each every both either
    neither own same such too again ever never always often sometimes still already yet soon later today tomorrow yesterday
    tonight morning evening night week month weekend hour minute second moment while during before since until till ago
    thing things something nothing anything everything someone anyone everyone nobody somebody anybody everybody somewhere
    man men woman women child children boy girl friend friends family mother father mom dad brother sister son daughter
    wife husband baby kid kids guy guys team boss client customer user users manager meeting meetings call calls email
    emails message messages text chat group office home house room door car road city country world place area name names
    life hand hands head eye eyes face body heart mind word words line page book story point fact case part side end start
    number numbers money price cost pay paid buy sell sold market business company job jobs project projects plan plans
    idea ideas problem problems issue issues question questions answer answers reason result results change changes
    information data report reports document file files code app apps phone computer laptop screen system program
    service services product products feature features update updates version release build test tests bug bugs fix
    fixed review deadline task tasks list note notes doc docs deck slide slides draft link links website site online
    water food tea coffee lunch dinner breakfast party trip travel flight ticket hotel school college class student
    teacher doctor hospital health market shop store bank account card order delivery address
    great big small large long short high low old young right wrong left next last early late hard easy best better
    worse worst sure true real full free open close closed ready happy sad nice fine okay ok cool awesome amazing important
    different possible available able whole certain clear simple quick fast slow busy late public private local
    black white red blue green yellow
    ask asked tell told call called try tried need needed feel felt become became leave left put mean meant keep kept let
    begin began seem seemed help helped talk talked turn turned show showed hear heard play played run ran move moved
    live lived believe hold held bring brought happen happened write wrote written sit sat stand stood lose lost meet met
    include continue set learn learned lead understand understood watch follow stop stopped create speak spoke read
    spend spent grow grew offer remember love loved consider appear wait waited serve die send sent expect build stay
    fall fell cut reach kill remain suggest raise pass sell require decide pull share shared check checked join joined
    finish finished schedule scheduled confirm confirmed cancel cancelled discuss reply replied sign signed thank thanks
    please sorry hello hi hey yes yeah yep nope bye welcome congratulations sir madam
    one two three four five six seven eight nine ten eleven twelve twenty thirty forty fifty hundred thousand million
    first second third half
    monday tuesday wednesday thursday friday saturday sunday january february march april may june july august
    september october november december
    i'm you're we're they're it's that's there's what's let's don't doesn't didn't can't won't isn't aren't wasn't
    weren't haven't hasn't hadn't wouldn't couldn't shouldn't i'll you'll we'll i've you've we've i'd you'd
    about above across against along among around behind below beneath beside between beyond inside outside through
    toward towards under upon within without off down near
    although though however therefore unless whether
    rise rose origin mark bill will grace hope joy faith rich
    """)

    private static let hinglish: Set<String> = words("""
    hai hain he main mein mai mera meri mere tera teri tere tum tumhara tumhari aap aapka aapki aapko hum humara hamara
    humari apna apni apne yeh ye woh wo voh vo uska uski uske unka unki unke inka inki iske uske kya kyu kyun kyon kyunki
    kyonki nahi nahin nhi nai na haan han ha haa toh to bhi aur ya ki ka ke ko se par pe tak liye lie wala wali wale
    kal aaj abhi kab jab tab kaise kaisa kaisi kahan kaha kidhar idhar udhar yahan yaha wahan waha kuch kuchh sab sabhi
    bahut bohot bahot bhot thoda thodi zyada jyada accha acha achha achchha achhi acchi theek thik chalo chal chalta
    karo kar karna karta karti karte kiya kiye kari hua hui hue ho hoga hogi honge raha rahi rahe rha rhi tha thi the
    gaya gayi gaye gya jaana jana ja jao jaa jaate aana ana aa aao aaya aayi aaye dekh dekho dekha dekhna bol bolo bola
    bolna sun suno suna sunna bata batao bataya batana de do diya dena dedo le lo liya lena lelo mil milo mila milna
    samajh samjha samjho pata lekin magar par phir fir jab agar waise vaise bas sirf yaar yar bhai bhaiya didi ji beta
    ghar kaam paisa paise log logon din raat subah shaam baat baatein baar ek teen char chaar paanch matlab sach jaldi
    dhire khana pani paani chai mat mujhe tujhe usko unko unhe humein hume tumhe kisi koi kaun kitna kitne kitni zaroor
    jarur shayad pehle baad kabhi hamesha naya nayi purana bada badi bade chhota chota choti dost pyaar pyar buri bura
    sahi galat mast arre are oye haina acha ji haanji nahi accha chahiye chahie sakta sakti sakte wapas abhi jaise
    vaisa waisa itna utna kaafi kafi bilkul ekdum zara jara kyaa kuchh mujhse tumse aapse unse isse usse humse
    """)

    private static func words(_ block: String) -> Set<String> {
        Set(block.split(whereSeparator: { $0.isWhitespace }).map { String($0) })
    }
}
