# Crypto Coders | Solidity DAO Voting System

قرارداد هوشمند سیستم رأی‌گیری سازمان مستقل غیرمتمرکز (DAO) به زبان Solidity با پشتیبانی از حد نصاب (Quorum) و سه گزینه رأی.

## ساختار فایل‌ها و قرارداد

| فایل | نام قرارداد | نسخه کامپایلر | توضیحات |
|---|---|---|---|
| `DAO.sol` | `DAOVotingSystem` | `^0.8.24` | مدیریت اعضای DAO، ایجاد پروپوزال، ثبت رأی و نهایی‌سازی نتایج بر اساس حد نصاب |

## ساختار داده‌ها و وضعیت‌ها
- `enum VoteChoice`: گزینه‌های رأی شامل `None`، `Agree` (موافق)، `Disagree` (مخالف) و `Abstain` (ممتنع)
- `enum ProposalStatus`: وضعیت‌های پروپوزال شامل `Active`، `Approved`، `Rejected` و `QuorumNotReached`
- `struct Proposal`: نگهداری شناسه، عنوان، توضیحات، پیشنهاددهنده، زمان شروع و پایان، حد نصاب (`quorum`)، شمارش آرا و وضعیت پروپوزال

## توابع اصلی
- `constructor(address[] memory _members)`: ثبت لیست اولیه اعضای DAO با بررسی عدم تکرار و معتبر بودن آدرس‌ها
- `createProposal(string _title, string _description, uint256 _duration, uint256 _quorum)`: ایجاد پروپوزال جدید توسط اعضای DAO (`onlyMember`)
- `castVote(uint256 _proposalId, VoteChoice _choice)`: ثبت رأی موافق، مخالف یا ممتنع توسط اعضا در مهلت قانونی (هر عضو یک رأی)
- `finalizeProposal(uint256 _proposalId)`: نهایی‌سازی وضعیت پروپوزال پس از پایان زمان رأی‌گیری بر اساس حد نصاب و اکثریت آرا
- `getProposal()`، `getVote()`، `getMembers()`، `getMemberCount()`، `getProposalCount()` و `isVotingOpen()`: توابع خواندنی وضعیت DAO
