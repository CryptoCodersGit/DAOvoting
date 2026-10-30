// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    نام قرارداد: DAOVotingSystem 

 * @title DAOVotingSystem
 * @author Crypto Coders
 * @notice سیستم داو - مدیریت رای گیری جمعی غیرمتمرکز
    هدف:
    پیاده‌سازی یک سیستم رأی‌گیری غیرمتمرکز (DAO Voting System)
    که در آن اعضا درباره پیشنهادهای مختلف تصمیم‌گیری می‌کنند.

    ویژگی‌های اصلی:
    1. اعضا فقط هنگام Deploy و در Constructor معرفی می‌شوند.
    2. پس از Deploy امکان اضافه یا حذف کردن اعضا وجود ندارد.
    3. هر عضو می‌تواند برای هر Proposal یک رأی فعال داشته باشد.
    4. رأی‌ها شامل Agree، Disagree و Abstain هستند.
    5. هر Proposal دارای مدت رأی‌گیری و حد نصاب (Quorum) است.
    6. پس از پایان مهلت، نتیجه باید با finalizeProposal نهایی شود.

    توجه:
    این قرارداد آموزشی است و پیش از استفاده واقعی باید
    به‌صورت مستقل بررسی امنیتی و تست شود.
*/

contract DAOVotingSystem {

    // ---------------------------------------------------------
    // 1. انواع رأی
    // ---------------------------------------------------------

    /*
        Enum برای تعریف گزینه‌های رأی‌گیری استفاده می‌شود.

        None:
            هنوز رأیی ثبت نشده است.

        Agree:
            عضو با پیشنهاد موافق است.

        Disagree:
            عضو با پیشنهاد مخالف است.

        Abstain:
            عضو در رأی‌گیری شرکت می‌کند، اما موافق یا مخالف نیست.

        مقادیر عددی این Enum به ترتیب:
        None = 0
        Agree = 1
        Disagree = 2
        Abstain = 3
    */
    enum VoteChoice {
        None,
        Agree,
        Disagree,
        Abstain
    }

    // ---------------------------------------------------------
    // 2. وضعیت نهایی Proposal
    // ---------------------------------------------------------

    /*
        Active:
            رأی‌گیری هنوز نهایی نشده است.

        Approved:
            حد نصاب تأمین شده و آرای موافق بیشتر از مخالف است.

        Rejected:
            حد نصاب تأمین شده، اما آرای مخالف بیشتر یا مساوی موافق است.

        QuorumNotReached:
            مهلت تمام شده، اما تعداد رأی‌دهندگان به حد نصاب نرسیده است.
    */
    enum ProposalStatus {
        Active,
        Approved,
        Rejected,
        QuorumNotReached
    }

    // ---------------------------------------------------------
    // 3. ساختار اطلاعات هر Proposal
    // ---------------------------------------------------------

    /*
        Struct به ما اجازه می‌دهد اطلاعات مرتبط با یک پیشنهاد
        را در قالب یک ساختار واحد ذخیره کنیم.

        هر Proposal شامل اطلاعات زیر است:
        - شناسه پیشنهاد
        - عنوان و توضیحات
        - آدرس سازنده پیشنهاد
        - زمان شروع و پایان رأی‌گیری
        - حد نصاب موردنیاز
        - تعداد رأی‌های هر گزینه
        - تعداد کل اعضایی که رأی داده‌اند
        - وضعیت فعلی یا نهایی پیشنهاد
    */
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;

        uint256 startTime;
        uint256 endTime;

        uint256 quorum;

        uint256 agreeVotes;
        uint256 disagreeVotes;
        uint256 abstainVotes;

        // تعداد اعضای رأی‌دهنده؛ هر عضو فقط یک بار شمرده می‌شود.
        uint256 totalVotes;

        ProposalStatus status;
    }

    // ---------------------------------------------------------
    // 4. تعریف اعضای ثابت DAO
    // ---------------------------------------------------------

    /*
        آرایه members آدرس تمام اعضای DAO را نگه می‌دارد.

        این آرایه فقط در Constructor مقداردهی می‌شود.
        در این قرارداد هیچ تابعی برای اضافه یا حذف اعضا نداریم.
    */
    address[] private members;

    /*
        این Mapping مشخص می‌کند که آیا یک آدرس عضو DAO است یا خیر.

        اگر:
        isMember[address] == true
        یعنی آن آدرس عضو DAO است.

        اگر false باشد، اجازه استفاده از توابع محدودشده به اعضا را ندارد.
    */
    mapping(address => bool) public isMember;

    // ---------------------------------------------------------
    // 5. ذخیره Proposalها
    // ---------------------------------------------------------

    /*
        هر Proposal با شناسه عددی خودش ذخیره می‌شود.

        مثال:
        proposals[0] = اولین پیشنهاد
        proposals[1] = دومین پیشنهاد
    */
    mapping(uint256 => Proposal) private proposals;

    /*
        تعداد کل Proposalهای ساخته‌شده.

        همچنین شناسه Proposal بعدی را مشخص می‌کند؛
        بنابراین اولین Proposal شناسه صفر خواهد داشت.
    */
    uint256 public proposalCount;

    // ---------------------------------------------------------
    // 6. ذخیره رأی هر عضو برای هر Proposal
    // ---------------------------------------------------------

    /*
        این Mapping تو در تو، رأی هر عضو را برای هر پیشنهاد ذخیره می‌کند.

        ساختار دسترسی:
        votes[proposalId][memberAddress]

        مثال:
        votes[0][0x123...] = VoteChoice.Agree

        اگر مقدار None باشد، آن عضو هنوز رأی نداده است.

        چون فقط یک مقدار برای هر عضو و Proposal ذخیره می‌شود،
        رأی جدید می‌تواند رأی قبلی را جایگزین کند.
    */
    mapping(uint256 => mapping(address => VoteChoice))
        public votes;

    // ---------------------------------------------------------
    // 7. رویدادهای قرارداد
    // ---------------------------------------------------------

    /*
        Eventها برای ثبت اتفاقات مهم قرارداد استفاده می‌شوند.
        رابط‌های کاربری و ابزارهای بررسی تراکنش می‌توانند
        این رویدادها را از لاگ تراکنش‌ها بخوانند.
    */

    // هنگام ایجاد یک Proposal منتشر می‌شود.
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 endTime,
        uint256 quorum
    );

    // هنگام ثبت رأی یا تغییر رأی عضو منتشر می‌شود.
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice choice
    );

    // هنگام نهایی شدن Proposal منتشر می‌شود.
    event ProposalFinalized(
        uint256 indexed proposalId,
        ProposalStatus result,
        uint256 agreeVotes,
        uint256 disagreeVotes,
        uint256 abstainVotes,
        uint256 totalVotes
    );

    // ---------------------------------------------------------
    // 8. Constructor: ثبت اعضا هنگام Deploy
    // ---------------------------------------------------------

    /*
        Constructor فقط یک بار، هنگام Deploy قرارداد اجرا می‌شود.

        ورودی:
        آرایه‌ای از آدرس‌های اعضا.

        در این حلقه:
        1. آدرس هر عضو خوانده می‌شود.
        2. آدرس صفر رد می‌شود.
        3. آدرس تکراری رد می‌شود.
        4. عضویت در Mapping ثبت می‌شود.
        5. آدرس در آرایه اعضا قرار می‌گیرد.

        پس از Deploy، اعضا قابل اضافه یا حذف شدن نیستند؛
        زیرا هیچ تابعی برای تغییر فهرست اعضا تعریف نشده است.
    */
    constructor(address[] memory _members) {
        require(_members.length > 0, "No members provided");

        // پیمایش تمام آدرس‌های ارسال‌شده به Constructor
        for (uint256 i = 0; i < _members.length; i++) {

            // آدرس عضو فعلی
            address member = _members[i];

            // جلوگیری از ثبت آدرس صفر
            require(member != address(0), "Invalid member");

            // جلوگیری از ثبت یک آدرس به‌عنوان چند عضو
            require(!isMember[member], "Duplicate member");

            // ثبت وضعیت عضویت
            isMember[member] = true;

            // افزودن آدرس به فهرست اعضا
            members.push(member);
        }
    }

    // ---------------------------------------------------------
    // 9. Modifier: محدود کردن دسترسی به اعضا
    // ---------------------------------------------------------

    /*
        Modifier قطعه‌ای از منطق است که می‌توان آن را
        قبل از اجرای تابع قرار داد.

        onlyMember بررسی می‌کند که msg.sender عضو DAO باشد.

        msg.sender:
        آدرسی که تراکنش را ارسال کرده است.

        اگر آدرس عضو نباشد، اجرای تراکنش با Revert متوقف می‌شود.
    */
    modifier onlyMember() {
        require(isMember[msg.sender], "Not a DAO member");
        _;
    }

    // ---------------------------------------------------------
    // 10. Modifier: بررسی وجود Proposal
    // ---------------------------------------------------------

    /*
        شناسه Proposal باید از صفر کوچک‌تر نباشد و از تعداد
        Proposalهای موجود نیز کمتر باشد.

        چون uint256 عدد منفی نمی‌پذیرد، فقط شرط دوم لازم است.
    */
    modifier proposalExists(uint256 _proposalId) {
        require(
            _proposalId < proposalCount,
            "Proposal does not exist"
        );
        _;
    }

    // ---------------------------------------------------------
    // 11. ایجاد Proposal جدید
    // ---------------------------------------------------------

    /*
        فقط اعضای DAO می‌توانند پیشنهاد ایجاد کنند.

        ورودی‌ها:
        _title:
            عنوان پیشنهاد.

        _description:
            توضیحات کامل پیشنهاد.

        _duration:
            مدت رأی‌گیری برحسب ثانیه.

        _quorum:
            حداقل تعداد اعضایی که باید رأی بدهند.

        خروجی:
        شناسه Proposal ساخته‌شده.
    */
    function createProposal(
        string calldata _title,
        string calldata _description,
        uint256 _duration,
        uint256 _quorum
    )
        external
        onlyMember
        returns (uint256)
    {
        // عنوان نباید خالی باشد.
        require(bytes(_title).length > 0, "Title required");

        // توضیحات نباید خالی باشد.
        require(
            bytes(_description).length > 0,
            "Description required"
        );

        // مدت رأی‌گیری باید بیشتر از صفر باشد.
        require(_duration > 0, "Duration must be positive");

        // حد نصاب باید حداقل یک رأی باشد.
        require(_quorum > 0, "Quorum must be positive");

        // حد نصاب نمی‌تواند از تعداد کل اعضا بیشتر باشد.
        require(
            _quorum <= members.length,
            "Quorum exceeds member count"
        );

        // شناسه Proposal جدید
        uint256 proposalId = proposalCount;

        /*
            block.timestamp زمان فعلی بلاک برحسب ثانیه است.

            با افزودن مدت رأی‌گیری، زمان پایان مشخص می‌شود.
        */
        uint256 endTime = block.timestamp + _duration;

        /*
            ذخیره اطلاعات Proposal در Mapping.

            در زمان ساخت:
            - تعداد همه رأی‌ها صفر است.
            - وضعیت Proposal برابر Active است.
            - زمان شروع برابر زمان فعلی بلاک است.
        */
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: _title,
            description: _description,
            proposer: msg.sender,
            startTime: block.timestamp,
            endTime: endTime,
            quorum: _quorum,
            agreeVotes: 0,
            disagreeVotes: 0,
            abstainVotes: 0,
            totalVotes: 0,
            status: ProposalStatus.Active
        });

        // افزایش تعداد Proposalها برای شناسه بعدی
        proposalCount++;

        // ثبت رویداد ایجاد پیشنهاد
        emit ProposalCreated(
            proposalId,
            msg.sender,
            _title,
            endTime,
            _quorum
        );

        // برگرداندن شناسه Proposal ساخته‌شده
        return proposalId;
    }

    // ---------------------------------------------------------
    // 12. ثبت رأی یا تغییر رأی قبلی
    // ---------------------------------------------------------

    /*
        فقط اعضای DAO می‌توانند رأی بدهند.

        هر عضو برای هر Proposal یک رأی فعال دارد.
        تا قبل از پایان مهلت می‌تواند رأی خود را تغییر دهد.

        مثال:
        اگر عضو ابتدا Agree و سپس Disagree انتخاب کند:
        - تعداد Agree یک واحد کم می‌شود.
        - تعداد Disagree یک واحد افزایش می‌یابد.
        - تعداد کل رأی‌دهندگان تغییر نمی‌کند.
    */
    function castVote(
        uint256 _proposalId,
        VoteChoice _choice
    )
        external
        onlyMember
        proposalExists(_proposalId)
    {
        // دسترسی به Proposal موردنظر از طریق Storage
        Proposal storage proposal = proposals[_proposalId];

        // Proposal باید هنوز نهایی نشده باشد.
        require(
            proposal.status == ProposalStatus.Active,
            "Proposal is not active"
        );

        // رأی‌گیری فقط پیش از زمان پایان باز است.
        require(
            block.timestamp < proposal.endTime,
            "Voting period has ended"
        );

        // None گزینه معتبر برای رأی دادن نیست.
        require(
            _choice != VoteChoice.None,
            "Invalid vote choice"
        );

        // خواندن رأی قبلی این عضو برای این Proposal
        VoteChoice previousChoice = votes[_proposalId][msg.sender];

        /*
            اگر عضو قبلاً رأی داده باشد، شمارنده رأی قبلی
            کاهش پیدا می‌کند.

            اگر برای اولین بار رأی بدهد، تعداد کل رأی‌دهندگان
            فقط یک واحد افزایش می‌یابد.
        */
        if (previousChoice != VoteChoice.None) {

            // حذف رأی قبلی از شمارنده مربوط به آن گزینه
            _decreaseVoteCount(proposal, previousChoice);

        } else {

            // عضو جدیدی به مشارکت‌کنندگان این Proposal اضافه شده
            proposal.totalVotes++;
        }

        // ذخیره انتخاب جدید عضو
        votes[_proposalId][msg.sender] = _choice;

        // افزایش شمارنده گزینه جدید
        _increaseVoteCount(proposal, _choice);

        // ثبت رویداد رأی
        emit VoteCast(_proposalId, msg.sender, _choice);
    }

    // ---------------------------------------------------------
    // 13. نهایی‌سازی نتیجه Proposal
    // ---------------------------------------------------------

    /*
        پس از پایان مهلت رأی‌گیری، این تابع نتیجه را تعیین می‌کند.

        نکته:
        این تابع را هر آدرسی می‌تواند فراخوانی کند؛
        اما فقط پس از پایان مهلت رأی‌گیری.

        قواعد نتیجه:
        1. اگر totalVotes کمتر از quorum باشد:
           QuorumNotReached

        2. اگر حد نصاب تأمین شده و Agree بیشتر از Disagree باشد:
           Approved

        3. در غیر این صورت:
           Rejected

        رأی Abstain در totalVotes حساب می‌شود،
        اما مستقیماً در مقایسه Agree و Disagree نقشی ندارد.
    */
    function finalizeProposal(
        uint256 _proposalId
    )
        external
        proposalExists(_proposalId)
    {
        Proposal storage proposal = proposals[_proposalId];

        // جلوگیری از نهایی‌سازی دوباره
        require(
            proposal.status == ProposalStatus.Active,
            "Proposal already finalized"
        );

        // تا پایان مهلت، نتیجه قابل نهایی‌سازی نیست.
        require(
            block.timestamp >= proposal.endTime,
            "Voting period has not ended"
        );

        // بررسی حد نصاب مشارکت
        if (proposal.totalVotes < proposal.quorum) {

            // مشارکت کمتر از حداقل تعیین‌شده بوده است.
            proposal.status = ProposalStatus.QuorumNotReached;

        } else if (
            proposal.agreeVotes > proposal.disagreeVotes
        ) {

            // رأی موافق بیشتر است و حد نصاب نیز تأمین شده.
            proposal.status = ProposalStatus.Approved;

        } else {

            /*
                اگر رأی مخالف بیشتر باشد، پیشنهاد رد می‌شود.
                اگر Agree و Disagree برابر باشند نیز پیشنهاد رد می‌شود.
            */
            proposal.status = ProposalStatus.Rejected;
        }

        // انتشار نتیجه نهایی و شمارنده‌های رأی
        emit ProposalFinalized(
            _proposalId,
            proposal.status,
            proposal.agreeVotes,
            proposal.disagreeVotes,
            proposal.abstainVotes,
            proposal.totalVotes
        );
    }

    // ---------------------------------------------------------
    // 14. تابع داخلی افزایش شمارنده رأی‌ها
    // ---------------------------------------------------------

    /*
        این تابع بر اساس نوع رأی، شمارنده مربوط را افزایش می‌دهد.

        internal:
        فقط خود قرارداد و قراردادهای مشتق‌شده می‌توانند
        مستقیماً این تابع را فراخوانی کنند.

        استفاده از این تابع باعث می‌شود منطق افزایش شمارنده‌ها
        در یک محل نگهداری شود و تکرار کد کاهش یابد.
    */
    function _increaseVoteCount(
        Proposal storage _proposal,
        VoteChoice _choice
    ) internal {

        // افزایش آرای موافق
        if (_choice == VoteChoice.Agree) {
            _proposal.agreeVotes++;

        // افزایش آرای مخالف
        } else if (_choice == VoteChoice.Disagree) {
            _proposal.disagreeVotes++;

        // افزایش آرای ممتنع
        } else if (_choice == VoteChoice.Abstain) {
            _proposal.abstainVotes++;
        }
    }

    // ---------------------------------------------------------
    // 15. تابع داخلی کاهش شمارنده رأی قبلی
    // ---------------------------------------------------------

    /*
        وقتی عضو رأی خود را تغییر می‌دهد، رأی قبلی باید
        از شمارنده گزینه قبلی کم شود.

        برای مثال:
        Agree -> Disagree

        agreeVotes یک واحد کاهش می‌یابد.
        سپس در تابع افزایش، disagreeVotes یک واحد زیاد می‌شود.

        در حالت تغییر رأی، totalVotes تغییر نمی‌کند؛
        چون تعداد مشارکت‌کنندگان جدیدی اضافه نشده است.
    */
    function _decreaseVoteCount(
        Proposal storage _proposal,
        VoteChoice _choice
    ) internal {

        // کاهش آرای موافق
        if (_choice == VoteChoice.Agree) {
            _proposal.agreeVotes--;

        // کاهش آرای مخالف
        } else if (_choice == VoteChoice.Disagree) {
            _proposal.disagreeVotes--;

        // کاهش آرای ممتنع
        } else if (_choice == VoteChoice.Abstain) {
            _proposal.abstainVotes--;
        }
    }

    // ---------------------------------------------------------
    // 16. دریافت تمام اطلاعات یک Proposal
    // ---------------------------------------------------------

    /*
        این تابع فقط اطلاعات را می‌خواند و تغییری در بلاکچین
        ایجاد نمی‌کند.

        view:
        تضمین می‌کند که تابع وضعیت ذخیره‌شده قرارداد را تغییر ندهد.

        خروجی:
        تمام فیلدهای Struct مربوط به Proposal.
    */
    function getProposal(
        uint256 _proposalId
    )
        external
        view
        proposalExists(_proposalId)
        returns (Proposal memory)
    {
        return proposals[_proposalId];
    }

    // ---------------------------------------------------------
    // 17. دریافت شمارنده رأی‌ها
    // ---------------------------------------------------------

    /*
        این تابع تعداد رأی‌های هر گزینه و تعداد کل مشارکت‌کنندگان
        را به‌صورت جداگانه برمی‌گرداند.

        خروجی‌ها:
        agree:
            تعداد رأی‌های موافق.

        disagree:
            تعداد رأی‌های مخالف.

        abstain:
            تعداد رأی‌های ممتنع.

        total:
            تعداد اعضایی که برای این Proposal رأی ثبت کرده‌اند.
    */
    function getVoteCounts(
        uint256 _proposalId
    )
        external
        view
        proposalExists(_proposalId)
        returns (
            uint256 agree,
            uint256 disagree,
            uint256 abstain,
            uint256 total
        )
    {
        Proposal storage proposal = proposals[_proposalId];

        return (
            proposal.agreeVotes,
            proposal.disagreeVotes,
            proposal.abstainVotes,
            proposal.totalVotes
        );
    }

    // ---------------------------------------------------------
    // 18. دریافت فهرست تمام اعضا
    // ---------------------------------------------------------

    /*
        آرایه کامل اعضا را برمی‌گرداند.

        memory:
        یک نسخه موقت از داده‌ها برای خروجی تابع ایجاد می‌شود.

        چون اعضا بعد از Deploy تغییر نمی‌کنند، این تابع
        برای مشاهده فهرست اعضای DAO کاربرد دارد.
    */
    function getMembers()
        external
        view
        returns (address[] memory)
    {
        return members;
    }

    // ---------------------------------------------------------
    // 19. دریافت تعداد اعضا
    // ---------------------------------------------------------

    /*
        تعداد کل اعضایی که در Constructor ثبت شده‌اند.
    */
    function getMemberCount()
        external
        view
        returns (uint256)
    {
        return members.length;
    }

    // ---------------------------------------------------------
    // 20. دریافت تعداد Proposalها
    // ---------------------------------------------------------

    /*
        تعداد Proposalهای ساخته‌شده تا این لحظه را برمی‌گرداند.
    */
    function getProposalCount()
        external
        view
        returns (uint256)
    {
        return proposalCount;
    }

    // ---------------------------------------------------------
    // 21. بررسی باز بودن رأی‌گیری
    // ---------------------------------------------------------

    /*
        خروجی true است اگر:
        1. وضعیت Proposal برابر Active باشد.
        2. هنوز به زمان پایان رأی‌گیری نرسیده باشیم.

        این تابع برای بررسی وضعیت رأی‌گیری در رابط کاربری
        یا هنگام تست قرارداد مفید است.
    */
    function isVotingOpen(
        uint256 _proposalId
    )
        external
        view
        proposalExists(_proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposals[_proposalId];

        return (
            proposal.status == ProposalStatus.Active &&
            block.timestamp < proposal.endTime
        );
    }
}
