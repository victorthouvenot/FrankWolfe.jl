using FrankWolfe
using ProgressMeter
using Arpack
using Plots
using DoubleFloats
using ReverseDiff
using Test

using LinearAlgebra

@testset "Approximate Caratheodory" begin
    n = Int(1e2)
    k = n
    f(x) = dot(x, x)
    function grad!(storage, x)
        @. storage = 2 * x
    end
    lmo = FrankWolfe.ProbabilitySimplexOracle{Rational{BigInt}}(1)
    x0 = FrankWolfe.compute_extreme_point(lmo, zeros(n))
    res1 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Agnostic(),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
    )
    x_true = [0.0003882741215298000420906058020008131649408310609791293789170887356180438746488335,
    0.01980198019801980174204644541789292442808870460109720167417109952972281608614392,
    0.0005824111822947000954662239221379876968608268608067998030881882653408599607928077,
    0.0007765482430596001991334434942656928089513067592163031453228607158571840579260239,
    0.0009706853038245001142071576214289134799237722821789055237774017039680826787031422,
    0.001164822364589400111184336970405283587112639773765304875456557608308253871966003,
    0.001358959425354300205152461976791955089903124178924704383577732186271746843393673,
    0.001553096486119200123613161507864747469883195782712153608246462591276847641400415,
    0.001747233546884100357294434425521019957092786851921236172277015496813510946277349,
    0.001941370607649000355084148151697916605542320405471402241189730786877249702816797,
    0.002135507668413900189066931434248524727347073349191061808421826725016298033411679,
    0.002329644729178800488410312568010179561296432106402094015372436636547190870300332,
    0.002523781789943700225565434613449155479169439923525110640264880421825234405418941,
    0.002717918850708600350269848067771177013721412922862882874142871429918104894240619,
    0.00291205591147350041570201695367579159623787972254067984203230754762306055249153,
    0.003106192972238400394560786197225285036706905836085303605037534758293128693317118,
    0.003300330033003300258916355706332062721509041503956562888727843249850295719733871,
    0.003494467093768200251325330593196232310842990450393933524221947330680444464801797,
    0.003688604154533100697556137630165387507087463584696562039873803199973987540303863,
    0.003882741215298000280510808464921223759615693413602755056045890689674985547160767,
    0.00407687827606290064532026901580120486067843846746828308661372200214047850445762,
    0.004271015336827800427670876015566418686819475875595140831696815232904816981848156,
    0.004465152397592700300644336281093783497378622647194256618042782330258695147220924,
    0.004659289458357600677783291847942320143740766052565949841229649920963748897450388,
    0.004853426519122500896862928565677777041960696594773910546541017125149389768231225,
    0.005047563579887400349929630024666106085486734275760558106092747026142268542084198,
    0.005241700640652300341005936027750888413411734405841787912836956874284273716155194,
    0.00543583770141720057436003632732971030264900193553537983270382110156803150697447,
    0.005629974762182100589292066545240496295677412189293474973894895544004801637854435,
    0.005824111822947000517638310026842471159962562890845771609185545744710134470069804,
    0.006018248883711900701932882326610513372895371860262337947266895500772264370506452,
    0.006212385944476800908128635903858300909265914693511109145245709075835008967892594,
    0.00640652300524170066422578228968641770665207338003948639873636061394374866678618,
    0.006600660066006600557359378411173783772985854572743890592194880849228212329337688,
    0.006794797126771500386545512812456811572419257253162939345016658340655232305565304,
    0.006988934187536401195686594588074609470046050625234469822884195336852657125810076,
    0.007183071248301300409266749345183476159104719175745343710122816828861705300913898,
    0.007377208309066200560061965330916936616011159980384306485951899215672861836708123,
    0.007571345369831101279899089099088304922555625123844674161593767025998054468133567,
    0.007765482430596001164881812390191680924328763077692843290633454302067358885193008,
    0.007959619491360900453909058475207330562637289289433195582248086795503407199549887,
    0.008153756552125800798928511006417766098936651650480496399871402018830343330168034,
    0.008347893612890701176534868560091450195396973866365810906807885915571452626113312,
    0.008542030673655601307967178640919486153647539009220933851635363471482090487691809,
    0.00873616773442050075078826721717919899202251630021742963554249833846591305019406,
    0.008930304795185400788816446073157731797754066857474622838211076501534872729621664,
    0.009124441855950300499031628042345539294270742940546650118460350669628920497759703,
    0.009318578916715200251694679550134014468299418906561575450695397869751669122905964,
    0.009512715977480101222301324703840348642382550557410309832498657210498216952646775,
    0.009706853038245000904973779903363673581004979002947935413756836518327343874430699,
    0.0099009900990099016320770682571002291766549020792077889481789544538601141709446,
    0.01009512715977480070330824787906891629563373076946674992991200547443165470943348,
    0.01028926422053970051637508985296103104660194327194007132380297848464365888908827,
    0.01048340128130460057964603797243673491034795241123139853761533363574100564529313,
    0.01067753834206950049433723497680551125679768720723401690218629975107771825032686,
    0.01087167540283440048137975861551520190308648645415513892201368413746230465165757,
    0.01106581246359930094519821056024475725539512769931169270997742942154266365415643,
    0.0112599495243642010776072982374634441426459478403852462389394401015731387373364,
    0.01145408658512910097148740796889579104395205691141874912211224599265740517284452,
    0.01164822364589400177634721185875880307334706151764883596750916727135335832714923,
    0.01184236070665890085000844219501227066229223105968599835591091296187120571031923,
    0.01203649776742380050795620263230436802814918235516324391622967535376103153864806,
    0.01223063482818870119508566421211684305164362598722788261331502425648517932718499,
    0.01242477188895360192566433248854698343239195924888124543133065605136144662402779,
    0.01261890894971850161645291494117749275706921765669271800234889834719208741784181,
    0.01281304601048340103366692941290102843591929193787306581993324382956797460467683,
    0.01300718307124830111155011896558288170400676047079890947090334808860479446565325,
    0.0132013201320132014764352267990904589902516307904252174466644298270810754193482,
    0.01339545719277810090490999756557855998351794416471997932888884896144015361937024,
    0.01358959425354300165770749624107258273621732815857823972553851445204449384523709,
    0.01378373131430790058353427727134755693341739798151426914212557635497450527288925,
    0.01397786837507280056989595539462618913710466709102404872348580950795279206680487,
    0.01417200543583770217307274924529067217964816864079098545083758936335685302700349,
    0.01436614249660260235270996444740609603744037097610924457965873509741432887767511,
    0.01456027955736750061985247998325491756704232592649562644968080288920001566116641,
    0.01475441661813240244569157876376825183183079469330507518766274847124142133175206,
    0.01494855367889730096019031098249851356565128185557548309989320843792554392292997,
    0.01514269073966220125547184677174924561603050296439632178532462686450923065046429,
    0.01533682780042710238420887516800915735472049531756248279604816939853819969912974,
    0.01553096486119200066827888284966917628380692198382831995136190350118819394452864,
    0.0157251019219569021087643008579889656067583836404881456889707058514564626115519,
    0.01591923898272180243140911317995190618158270529328470342331381641626380482146769,
    0.01611337604348670070620444686537384592071367002483289832602471899478622134821486,
    0.01630751310425160138819624759733579805501498450009937461693400873057554799529194,
    0.01650165016501650139926986008137823799559838250160816524032817173921091857383403,
    0.01669578722578140141028007979048119408425319324677463861957170414247959742750423,
    0.01688992428654630214076512442467616982886122586518095906913109519577109285864251,
    0.01708406134731120120611506433379078225892196616485648363362907091079387525566909,
    0.01727819840807610237377742877896019445606740817927518800647707479448108625659192,
    0.01747233546884100312822173580837901199072761007053886286328615959502762658879238,
    0.01766647252960590128265011872399721132014544232993445792944682128778320059295789,
    0.0178606095903708032490284312604307728446385580457409920995885098087747905279215,
    0.01805474665113570139561221383225131733707823572401386027164683146405154870468538,
    0.01824888371190060143342528481993271072179130589404018055997421790869707617200101,
    0.01844302077266550081901437253928410048000392634317940606703856904328115317566703,
    0.01863715783343040149908517569608539728431614317130150542900034863564971816073049,
    0.01883129489419530034004655890248654653852444965838982238279157704916206502274489,
    0.01902543195496020351226333102072831389732383717536576363318028356443370391048994,
    0.01921956901572510232266421678436112468933955605034956800251944650364831594880664,
    0.01941370607649000218250087532506190641350721586961201686937898271255334512602753]
    primal_true = 0.01314422099649411305714214236596045839642713180124049726321024688069930261252318
    @test norm(res1[1] - x_true) ≈ 0 atol = 1e-6
    @test res1[3] ≈ primal_true

    res2 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Shortstep(2 // 1),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
    )
    x_true = [0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01,
    0.01
    ]
    primal_true = 0.01
    @test norm(res2[1] - x_true) ≈ 0 atol = 1e-6
    @test res2[3] ≈ primal_true

end

@testset "Approximate Caratheodory with random initialization" begin
    rhs = 1
    k = 1e5
    x_true = [61512951376323730454002197150348389314089326897787615721998692413353959632437//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    7278301191941549131183323094243942700957644187929251522094354780914218275643//7410693711188236507108543040556026102609279018600996098525285376506440296955904,
    8366562124555104321121369841697389597845181508166497753247502851926662059563//231584178474632390847141970017375815706539969331281128078915168015826259279872,
    85023391065000333202828293111143357401972379805025875286177370028514589002563//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    65161147193679930666908924856262469104197138809185702944157386640936864997051//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    79601478169795915975697070307050727165420854919928218988885008389058048219799//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    67837373726039687662074349377195592477915195880054271380448921303995127196787//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    55169871312251590938351075012017608231499182261935245722772561815939463686945//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    86815771044534708965244863268893818174646630872044525249352735709981389751563//29642774844752946028434172162224104410437116074403984394101141506025761187823616,
    72336771117105959301574221890003216380657564844338588751171518976178113048017//29642774844752946028434172162224104410437116074403984394101141506025761187823616,
    19890931658710480666057076719356895452123545713808612893617662915732470931561//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    79585978057301384008717145909924897970180606286778393928727017924984613374659//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    113965904146211811471977184949419222372334011462703157205004739574650127142033//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    5428354262203226529922598481638522646897396408804020092482524536075502397089//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    34827625827775960484301801523292094477572109942336300722774749588002270047107//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    8144733136987354412249131885422478920455820770248694226860937021089948464221//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    83223495385376576134214902972508569795914027222867150904993148656647549582643//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    54297750348315411085069411691276033515094776339188270147174153874826550949759//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    37999445234583642959973667475688948272912144623017138000156880088920795412827//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    79609315854867434707411488589752461150308986825456950218827676254431104225223//14821387422376473014217086081112052205218558037201992197050570753012880593911808,
    36228520792880844351408349957314092789406418697994688604833502039464381047593//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    87747074626700853575232381986258310602806824140384221969315398151119893566027//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    14247237619794261330995555194505323439550547179850901735114007176618394961353//463168356949264781694283940034751631413079938662562256157830336031652518559744,
    14248684606965137684515955910711963166771474351946426521187714925472414576673//463168356949264781694283940034751631413079938662562256157830336031652518559744,
    84150822879115430935288141198806087582607671818743223481767144916744174202711//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    80512422222849887485621734147521502765322572979265885473937061004907501946415//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    13575133430342896240925710532529889229904841799812827659124544788029451500505//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    85930842192362005344537760883863364225750024310074067572323399741581216569741//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    65021782163379251030074430456678178405938486301538530120830779975596245752847//14821387422376473014217086081112052205218558037201992197050570753012880593911808,
    40701251232106608633770622134695258535560875020915747471858891813546395472325//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    39798030372341094444100232335522337649867082740716224935897408719862574204305//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    84121644147995396625591066877556253744715337783486488304563392406881190793051//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    33922055663316267391672695885159354882451875454551025177383028349114163057371//926336713898529563388567880069503262826159877325124512315660672063305037119488,
    15831205501799787359855727259669406012682835451292628159505016130571475753067//463168356949264781694283940034751631413079938662562256157830336031652518559744,
    97667231102575253732993923620041238774510608407541976676513500282167400753847//7410693711188236507108543040556026102609279018600996098525285376506440296955904,
    61506200807405941080369582838580555432120089840841225703478555148085366801593//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    69663077113345636859399373513055005486354570697173148668421658523479885425043//1852673427797059126777135760139006525652319754650249024631321344126610074238976,
    101464980607353895107673290372367186084458336535036844511537017865818241482095//29642774844752946028434172162224104410437116074403984394101141506025761187823616,
    30762334036323628501430433726571171454828575613210821709890893791022869772097//3705346855594118253554271520278013051304639509300498049262642688253220148477952,
    29403498868980333524589803906472036743111538604830514310901745746061273020257//926336713898529563388567880069503262826159877325124512315660672063305037119488]
    primal_true = 9.827847816235913956551323164596263945321701473649212104977642156975401442102586e-10
    xp = [17//1024,
    1//1024,
    37//1024,
    47//1024,
    9//512,
    11//256,
    75//2048,
    61//2048,
    3//1024,
    5//2048,
    11//2048,
    11//512,
    63//2048,
    3//512,
    77//2048,
    9//1024,
    23//1024,
    15//512,
    21//512,
    11//2048,
    5//512,
    97//2048,
    63//2048,
    63//2048,
    93//2048,
    89//2048,
    15//1024,
    95//2048,
    9//2048,
    45//2048,
    11//512,
    93//2048,
    75//2048,
    35//1024,
    27//2048,
    17//512,
    77//2048,
    7//2048,
    17//2048,
    65//2048]
    direction = [0.00928107242432663,
    0.3194042202333671,
    0.7613490224961625,
    0.9331502775657023,
    0.5058966756232495,
    0.7718148164937879,
    0.3923111977240855,
    0.12491790837874406,
    0.8485975494086246,
    0.453457809041527,
    0.43297176382458114,
    0.6629759429794072,
    0.8986003842140354,
    0.6074039179253773,
    0.9114822007027404,
    0.04278632498941526,
    0.352674631558033,
    0.7886492242572878,
    0.7952842710030733,
    0.7874206770511923,
    0.7726147629233262,
    0.6012149427173692,
    0.13299869717521284,
    0.49058432205062985,
    0.57373575784723,
    0.9237295811565405,
    0.13315214983763268,
    0.3558682954823691,
    0.8655648010180531,
    0.2246697359783949,
    0.5047341378190603,
    0.34094108472913265,
    0.11227329675627062,
    0.27474436461569807,
    0.1803131027661613,
    0.5219938641083894,
    0.6233658038612543,
    0.2217260674856315,
    0.5254499622424393,
    0.14597502257203032]

    f(x) = norm(x - xp)^2
    function grad!(storage, x)
        @. storage = 2 * (x - xp)
    end

    lmo = FrankWolfe.ProbabilitySimplexOracle{Rational{BigInt}}(rhs)
    x0 = FrankWolfe.compute_extreme_point(lmo, direction)

    res3 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Agnostic(),
        print_iter=k / 10,
        memory_mode=FrankWolfe.InplaceEmphasis(),
        verbose=false,
    )

    @test norm(res3[1] - x_true) ≈ 0 atol = 1e-6
    @test res3[3] ≈ primal_true
end
