const rates = { AMD: 390, RUB: 90, USD: 1 };
window.bidstageRates = rates;
const symbols = { AMD: 'AMD', RUB: '₽', USD: '$' };
const fractionDigits = { AMD: 0, RUB: 0, USD: 2 };
let currentCurrency = localStorage.getItem('bs.currency') || 'AMD';
let currentLang = localStorage.getItem('bs.lang') || 'ru';
window.currentCurrency = currentCurrency;
let selectedLot = null;
let socket = null;
let liveBidsAdded = new Set();

const I18N = {
  ru: {
    'nav.home': 'Главная',
    'nav.active': 'Активные торги',
    'nav.how': 'Как работает',
    'nav.hall': '🏆 Зал славы',
    'nav.sell': '+ Продать',
    'nav.profile': 'Профиль',
    'nav.chats': 'Чаты',
    'header.online': 'в сети',
    'header.login': 'Войти',
    'header.signup': 'Регистрация',
    'header.logout': 'Выйти',
    'badge.live': 'идёт',
    'badge.endingSoon': '⏰ скоро финал',
    'badge.finalHour': 'Финальный час',
    'badge.reserveMet': 'Резерв пройден',
    'status.active': 'Идёт',
    'status.ended': 'Завершён',
    'status.upcoming': 'Скоро',
    'time.endsIn': 'До конца',
    'time.lessHour': 'Меньше часа',
    'time.ended': 'Завершён',
    'time.soon': 'Скоро',
    'lot.bid': 'Сделать ставку',
    'lot.currentBid': 'Текущая ставка',
    'lot.step': 'Шаг',
    'lot.type.tickets': 'Билеты',
    'lot.type.vip': 'VIP-пропуск',
    'lot.type.table': 'Стол',
    'lot.bidsActive': 'активных ставок',
    'lot.totalBids': 'всего ставок',
    'lot.verified': 'подтверждено',
    'lot.bidders': 'биддеров',
    'lot.history': 'История ставок',
    'lot.activity': 'Активность',
    'lot.last': 'последние',
    'lot.bidsCount': 'ставок',
    'lot.minBid': 'Сделать ставку от',
    'lot.feed': '📡 Лента событий',
    'lot.podium': '🏆 Подиум',
    'lot.share': 'Поделиться',
    'lot.rules': 'Правила',
    'lot.timer': 'До конца',
    'lot.startPrice': 'Стартовая',
    'lot.minimum': 'Минимум',
    'lot.growth': 'Прирост',
    'lot.concertDate': 'Дата концерта',
    'lot.endTime': 'Конец торгов',
    'lot.duration': 'Длительность',
    'lot.description': 'Описание',
    'lot.viewers': 'смотрят',
    'common.cancel': 'Отмена',
    'common.confirm': 'Подтвердить',
    'common.networkError': 'Сетевая ошибка',
    'common.loading': 'Загрузка...',
    'common.back': 'Назад в каталог',
    'common.activity': 'Активность',
    'bid.tooLow': 'Сумма меньше минимальной',
    'bid.duplicate': 'Вы уже делали такую же ставку',
    'bid.lotEnded': 'Аукцион уже завершён',
    'bid.notActive': 'Аукцион неактивен',
    'bid.invalidShareUrl': 'Вставьте корректную ссылку на пост',
    'bid.shareIsNotPost': 'Это окно шеринга, не пост. Откройте профиль VK, найдите пост и скопируйте URL с него.',
    'bid.insufficientFunds': 'Недостаточно средств для этой ставки',
    'bid.minimum': 'Минимальная ставка',
    'sell.feeListing': 'Листинг',
    'sell.feeFeatured': 'Поднять в топ',
    'sell.publish': 'Опубликовать',
    'profile.balance': 'Баланс',
    'profile.balanceNote': 'USD · конвертируется при оплате',
    'profile.activity': 'Активность',
    'profile.myBids': 'Мои ставки',
    'profile.topup': 'Пополнение',
    'profile.topupBtn': 'Пополнить',
    'profile.topupHint': '«С карты» спишет с карты по умолчанию мгновенно.',
    'profile.providerCard': 'С карты',
    'profile.providerDemo': 'Демо',
    'profile.settingsTitle': 'Настройки',
    'profile.settingsSubtitle': 'Валюта и язык интерфейса',
    'profile.currency': 'Валюта отображения',
    'profile.currencyHint': 'Применится сразу на всём сайте.',
    'profile.language': 'Язык',
    'profile.languageHint': 'Переводит интерфейс. Названия и описания лотов переводятся при загрузке страницы.',
    'profile.cards': 'Карты',
    'profile.cardsTitle': 'Платёжные методы',
    'profile.cardsHint': 'При победе сумма списывается с карты по умолчанию.',
    'profile.addCard': 'Привязать карту',
    'profile.watchlist': 'Слежу за лотами',
    'profile.favorites': 'Избранное',
    'profile.history': 'История покупок',
    'profile.escrow': 'Эскроу и платежи',
    'profile.escrowHint': 'Деньги хранятся в эскроу до подтверждения получения билета.',
    'profile.confirmDelivery': 'Подтвердить получение и освободить деньги',
    'profile.profile': 'Профиль',
    'hero.premium': 'ПРЕМИУМ',
    'hero.auction': 'АУКЦИОН',
    'hero.subtitle': 'Концертные лоты, VIP-столы и бэкстейдж-моменты в формате торгов в реальном времени. Чтобы ставка засчиталась — поделись лотом в соцсетях.',
    'catalog.hotTitle': '🔥 Горящие лоты',
    'catalog.hotSubtitle': 'Заканчиваются скоро',
    'catalog.topTitle': '⭐ Топ',
    'catalog.topSubtitle': 'Продвинутые аукционы',
    'catalog.topTitle': '⭐ Топ',
    'catalog.topSubtitle': 'Продвинутые аукционы',
    'catalog.title': 'Каталог',
    'catalog.subtitle': 'Концертные лоты',
    'filter.active': 'Активные',
    'filter.ended': 'Завершены',
    'filter.upcoming': 'Скоро',
    'modal.terminal': 'Терминал ставок',
    'modal.minimum': 'Минимум',
    'modal.continue': 'Продолжить',
    'modal.manual': 'Ручная',
    'modal.autobid': '⚡ Автоставка',
    'modal.autobidHint': '⚡ Автоставка: система автоматически перебивает соперников до этой суммы.',
    'modal.bidAmount': 'Сумма ставки',
    'modal.plus1step': '+1 шаг',
    'modal.plus3steps': '+3 шага',
    'modal.plus5steps': '+5 шагов',
    'chat.title': '💬 Чат с продавцом',
    'chat.loading': 'Загрузка...',
    'sell.image': 'Картинка лота',
    'sell.imageDrop': 'Перетащите картинку или нажмите',
    'sell.imageHint': 'JPG, PNG, WebP или GIF до 6 МБ. Опционально.',
    'lot.activityHourly': 'Активность по часам',
    'lot.hours': 'ч',
    'rules.minBid': 'Ставка минимум',
    'rules.share': 'Поделитесь лотом в VK/FB',
    'rules.keepPost': 'Не удаляйте пост до конца',
    'rules.payIn24h': 'Оплатите выигрыш за 24 ч',
    'hall.eyebrow': '🏆 Hall of fame',
    'hall.title': 'Зал славы',
    'hall.subtitle': 'Лучшие лоты, самые упорные биддеры и легендарные битвы платформы.',
    'hall.mostExpensive': '💎 Самый дорогой',
    'hall.hardestBattle': '⚔️ Самая упорная битва',
    'hall.biggestGrowth': '📈 Максимальный рост',
    'hall.topBuyer': '👑 Король покупателей',
    'hall.topSeller': '⭐ Топ продавец',
    'hall.mostPersistent': '🔥 Самый настойчивый',
    'hall.openLot': 'Открыть лот',
    'hall.bidsMade': 'ставок сделано',
    'hall.wins': 'побед',
    'hall.totalSpent': 'общая сумма выигрышей',
    'hall.profile': 'профиль продавца',
    'hall.soldLots': 'проданных лотов',
    'hall.neverGivesUp': 'никогда не сдаётся',
    'hall.totalBidsAllTime': 'ставок за всё время',
    'hall.joinAuction': 'Поучаствовать в торгах',
    'how.back': 'Назад на главную',
    'how.eyebrow': 'Инструкция',
    'how.title': 'Как работает BidStage',
    'how.subtitle': 'Аукцион концертных лотов: чем выше ставка — тем ближе вы к билету. Чтобы ставка засчиталась, нужно поделиться лотом в соцсети.',
    'how.start': 'Старт', 'how.bid': 'Ставка', 'how.share': 'Шара', 'how.timer': 'Таймер', 'how.win': 'Победа', 'how.ticket': 'Билет',
    'how.s1.title': '01 — Регистрация', 'how.s1.body': 'Создайте аккаунт по email или войдите через демо-юзера. Привяжите карту в профиле для мгновенной оплаты.',
    'how.s2.title': '02 — Сделайте ставку', 'how.s2.body': 'Минимум — текущая цена + шаг. Доступна автоставка: установите максимум, система сама перебивает соперников.',
    'how.s3.title': '03 — Поделитесь лотом', 'how.s3.body': 'Опубликуйте пост в VK или FB и пришлите ссылку на пост. Система автоматически проверит — если удалите пост, ставка аннулируется.',
    'how.s4.title': '04 — Анти-снайпинг', 'how.s4.body': 'Ставка в последние 3 минуты автоматически продлевает торги на 180 секунд. Это защита от поздних снайперов.',
    'how.s5.title': '05 — Оплата', 'how.s5.body': 'Победитель оплачивает выигрыш картой за 24 часа. Не оплатил — лот переходит к следующему биддеру.',
    'how.s6.title': '06 — Электронный билет', 'how.s6.body': 'После оплаты вы получаете уникальный 32-значный код билета. Деньги в эскроу — продавец получит их только после подтверждения доставки.',
    'how.protectBuyer': 'Защита покупателя',
    'how.protectBuyerBody': 'Деньги хранятся в эскроу. Продавец получит выплату только после того, как вы подтвердите получение билета.',
    'how.protectSeller': 'Защита продавца',
    'how.protectSellerBody': 'Каждая ставка обеспечена обязательным шерингом и проверкой через VK API. Накрутить ставки сложнее.',
    'how.cascade': 'Каскад платежей',
    'how.cascadeBody': 'Если победитель не оплатил — лот переходит ко второму. Не оплатил и он — снова в продажу с тем же таймером.',
    'how.fees': 'Тарифы продавца', 'how.feeListing': 'Листинг', 'how.feeFeatured': 'Поднять в топ (Featured)', 'how.feeFinal': 'Комиссия с продажи',
    'how.feesNote': 'Если лот не продаётся, листинг не возвращается, но процент с продажи не списывается.',
    'how.providers': 'Платёжные провайдеры', 'how.armenia': 'Армения', 'how.russia': 'Россия', 'how.world': 'Другие страны',
    'how.providerNote': 'Система автоматически выбирает провайдера по стране в вашем профиле.',
    'how.toHome': 'На главную', 'how.signup': 'Создать аккаунт', 'how.listLot': 'Выставить свой лот',
    'sell.newLot': 'Новый лот', 'sell.paidListing': 'Платный листинг',
    'sell.createTitle': 'Создать аукцион',
    'sell.createSubtitle': 'Выставите свой лот на торги. Платформа берёт листинговую комиссию и процент с финальной продажи.',
    'sell.lotName': 'Название лота', 'sell.artist': 'Артист / Событие', 'sell.type': 'Тип лота', 'sell.description': 'Описание',
    'sell.startPrice': 'Стартовая цена', 'sell.bidStep': 'Шаг ставки', 'sell.priceCurrency': 'Валюта цен',
    'sell.concertDate': 'Дата концерта', 'sell.duration': 'Длительность торгов',
    'sell.dur1h': '1 час (тест)', 'sell.dur24h': '24 часа', 'sell.dur2d': '2 дня', 'sell.dur3d': '3 дня', 'sell.dur1w': '1 неделя', 'sell.dur2w': '2 недели', 'sell.durCustom': 'Свой вариант…',
    'sell.feature': 'Поднять в топ', 'sell.featureBody': 'Лот будет показываться в начале каталога с бейджем «Featured». Привлекает в 3-5 раз больше ставок.',
    'sell.publish': 'Опубликовать',
    'sell.yourBalance': 'Ваш баланс', 'sell.inEscrow': '🔒 В эскроу', 'sell.escrowHint': 'Поступит после подтверждения покупателей',
    'sell.topup': 'Пополнить',
    'sell.myAuctions': 'Мои аукционы', 'sell.lotHistory': 'История лотов', 'sell.fees': 'Тарифы',
    'sell.escrowSection': '🔒 Эскроу', 'sell.escrowDeals': 'Сделки в обработке',
    'sell.escrowDealsHint': 'Отправьте билет покупателю. Деньги поступят на ваш баланс после подтверждения получения.',
    'profile.awaitsPayment': 'Ожидает оплаты',
    'profile.youWon': 'Вы выиграли · оплатите выигрыш',
    'profile.notPaidNote': 'Если не оплатить до срока — лот перейдёт следующему биддеру.',
    'profile.payCard': 'Оплатить картой',
    'profile.payBalance': 'Списать с баланса',
  },
  en: {
    'nav.home': 'Home',
    'nav.active': 'Live auctions',
    'nav.how': 'How it works',
    'nav.hall': '🏆 Hall of fame',
    'nav.sell': '+ Sell',
    'nav.profile': 'Profile',
    'nav.chats': 'Chats',
    'header.online': 'online',
    'header.login': 'Sign in',
    'header.signup': 'Sign up',
    'header.logout': 'Log out',
    'badge.live': 'live',
    'badge.endingSoon': '⏰ ending soon',
    'badge.finalHour': 'Final hour',
    'badge.reserveMet': 'Reserve met',
    'status.active': 'Live',
    'status.ended': 'Ended',
    'status.upcoming': 'Upcoming',
    'time.endsIn': 'Ends in',
    'time.lessHour': 'Less than an hour',
    'time.ended': 'Ended',
    'time.soon': 'Soon',
    'lot.bid': 'Place a bid',
    'lot.currentBid': 'Current bid',
    'lot.step': 'Step',
    'lot.type.tickets': 'Tickets',
    'lot.type.vip': 'VIP pass',
    'lot.type.table': 'Table',
    'lot.bidsActive': 'active bids',
    'lot.totalBids': 'total bids',
    'lot.verified': 'verified',
    'lot.bidders': 'bidders',
    'lot.history': 'Bid history',
    'lot.activity': 'Activity',
    'lot.last': 'latest',
    'lot.bidsCount': 'bids',
    'lot.minBid': 'Bid from',
    'lot.feed': '📡 Live feed',
    'lot.podium': '🏆 Podium',
    'lot.share': 'Share',
    'lot.rules': 'Rules',
    'lot.timer': 'Ends in',
    'lot.startPrice': 'Starting',
    'lot.minimum': 'Minimum',
    'lot.growth': 'Growth',
    'lot.concertDate': 'Concert date',
    'lot.endTime': 'Auction ends',
    'lot.duration': 'Duration',
    'lot.description': 'Description',
    'lot.viewers': 'watching',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.networkError': 'Network error',
    'common.loading': 'Loading...',
    'common.back': 'Back to catalogue',
    'common.activity': 'Activity',
    'bid.tooLow': 'Amount is below minimum',
    'bid.duplicate': 'Duplicate bid',
    'bid.lotEnded': 'Auction has ended',
    'bid.notActive': 'Auction is not active',
    'bid.invalidShareUrl': 'Paste a valid post URL',
    'bid.shareIsNotPost': 'This is a share dialog URL, not a post. Open your VK profile and copy the post URL.',
    'bid.insufficientFunds': 'Not enough balance for this bid',
    'bid.minimum': 'Minimum bid',
    'sell.feeListing': 'Listing',
    'sell.feeFeatured': 'Featured',
    'sell.publish': 'Publish',
    'profile.balance': 'Balance',
    'profile.balanceNote': 'USD · converted at checkout',
    'profile.activity': 'Activity',
    'profile.myBids': 'My bids',
    'profile.topup': 'Top up',
    'profile.topupBtn': 'Top up',
    'profile.topupHint': '«From card» charges the default card instantly.',
    'profile.providerCard': 'From card',
    'profile.providerDemo': 'Demo',
    'profile.settingsTitle': 'Settings',
    'profile.settingsSubtitle': 'Currency and language',
    'profile.currency': 'Display currency',
    'profile.currencyHint': 'Applies everywhere on the site.',
    'profile.language': 'Language',
    'profile.languageHint': 'Translates the interface. Lot titles and descriptions are translated when the page loads.',
    'profile.cards': 'Cards',
    'profile.cardsTitle': 'Payment methods',
    'profile.cardsHint': 'When you win, your default card is charged.',
    'profile.addCard': 'Add card',
    'profile.watchlist': 'Watching',
    'profile.favorites': 'Favorites',
    'profile.history': 'Purchase history',
    'profile.escrow': 'Escrow & payments',
    'profile.escrowHint': 'Funds are held in escrow until you confirm receiving the ticket.',
    'profile.confirmDelivery': 'Confirm delivery and release funds',
    'profile.profile': 'Profile',
    'hero.premium': 'PREMIUM',
    'hero.auction': 'AUCTION',
    'hero.subtitle': 'Concert lots, VIP tables and backstage moments — bid in real time. To make a bid count, share the lot on social media.',
    'catalog.hotTitle': '🔥 Hot lots',
    'catalog.hotSubtitle': 'Ending soon',
    'catalog.topTitle': '⭐ Top',
    'catalog.topSubtitle': 'Featured auctions',
    'catalog.topTitle': '⭐ Top',
    'catalog.topSubtitle': 'Featured auctions',
    'catalog.title': 'Catalogue',
    'catalog.subtitle': 'Concert lots',
    'filter.active': 'Live',
    'filter.ended': 'Ended',
    'filter.upcoming': 'Upcoming',
    'modal.terminal': 'Bid terminal',
    'modal.minimum': 'Minimum',
    'modal.continue': 'Continue',
    'modal.manual': 'Manual',
    'modal.autobid': '⚡ Autobid',
    'modal.autobidHint': '⚡ Autobid: system raises against rivals up to this amount.',
    'modal.bidAmount': 'Bid amount',
    'modal.plus1step': '+1 step',
    'modal.plus3steps': '+3 steps',
    'modal.plus5steps': '+5 steps',
    'chat.title': '💬 Chat with seller',
    'chat.loading': 'Loading...',
    'sell.image': 'Lot image',
    'sell.imageDrop': 'Drop an image or click',
    'sell.imageHint': 'JPG, PNG, WebP or GIF up to 6 MB. Optional.',
    'lot.activityHourly': 'Hourly activity',
    'lot.hours': 'h',
    'rules.minBid': 'Minimum bid',
    'rules.share': 'Share the lot on VK/FB',
    'rules.keepPost': 'Do not delete the post until the end',
    'rules.payIn24h': 'Pay the winning bid within 24h',
    'hall.eyebrow': '🏆 Hall of fame',
    'hall.title': 'Hall of fame',
    'hall.subtitle': 'Best lots, most determined bidders and legendary battles of the platform.',
    'hall.mostExpensive': '💎 Most expensive',
    'hall.hardestBattle': '⚔️ Toughest battle',
    'hall.biggestGrowth': '📈 Biggest growth',
    'hall.topBuyer': '👑 Top buyer',
    'hall.topSeller': '⭐ Top seller',
    'hall.mostPersistent': '🔥 Most persistent',
    'hall.openLot': 'Open lot',
    'hall.bidsMade': 'bids made',
    'hall.wins': 'wins',
    'hall.totalSpent': 'total spent',
    'hall.profile': 'seller profile',
    'hall.soldLots': 'lots sold',
    'hall.neverGivesUp': 'never gives up',
    'hall.totalBidsAllTime': 'bids all-time',
    'hall.joinAuction': 'Join the auction',
    'how.back': 'Back to home',
    'how.eyebrow': 'Guide',
    'how.title': 'How BidStage works',
    'how.subtitle': 'A concert lot auction: the higher your bid, the closer you are to the ticket. For a bid to count, you must share the lot on social media.',
    'how.start': 'Start', 'how.bid': 'Bid', 'how.share': 'Share', 'how.timer': 'Timer', 'how.win': 'Win', 'how.ticket': 'Ticket',
    'how.s1.title': '01 — Sign up', 'how.s1.body': 'Create an account by email or use a demo user. Add a card in your profile for instant payments.',
    'how.s2.title': '02 — Place a bid', 'how.s2.body': 'Minimum equals current price plus step. Auto-bid is available: set your max and the system outbids opponents for you.',
    'how.s3.title': '03 — Share the lot', 'how.s3.body': 'Publish a post on VK or FB and submit the post URL. The system verifies it — delete the post and your bid is voided.',
    'how.s4.title': '04 — Anti-sniping', 'how.s4.body': 'A bid in the last 3 minutes automatically extends the auction by 180 seconds — protection against late snipers.',
    'how.s5.title': '05 — Payment', 'how.s5.body': 'The winner pays by card within 24 hours. If unpaid, the lot goes to the next highest bidder.',
    'how.s6.title': '06 — Digital ticket', 'how.s6.body': 'After payment you get a unique 32-character ticket code. Funds stay in escrow — the seller receives them only after you confirm delivery.',
    'how.protectBuyer': 'Buyer protection',
    'how.protectBuyerBody': 'Funds are held in escrow. The seller is paid only after you confirm receiving the ticket.',
    'how.protectSeller': 'Seller protection',
    'how.protectSellerBody': 'Every bid is backed by a mandatory share and VK API verification. Spam bids become much harder.',
    'how.cascade': 'Payment cascade',
    'how.cascadeBody': 'If the winner does not pay, the lot is offered to the next bidder. If they fail too, it relists with the same timer.',
    'how.fees': 'Seller fees', 'how.feeListing': 'Listing', 'how.feeFeatured': 'Featured', 'how.feeFinal': 'Final value fee',
    'how.feesNote': 'If the lot does not sell, the listing fee is not refunded, but the final value fee is not charged.',
    'how.providers': 'Payment providers', 'how.armenia': 'Armenia', 'how.russia': 'Russia', 'how.world': 'Other countries',
    'how.providerNote': 'The system picks the provider based on your country in profile.',
    'how.toHome': 'Home', 'how.signup': 'Create account', 'how.listLot': 'List a lot',
    'sell.newLot': 'New lot', 'sell.paidListing': 'Paid listing',
    'sell.createTitle': 'Create an auction',
    'sell.createSubtitle': 'List your lot for bidding. The platform charges a listing fee and a final value fee.',
    'sell.lotName': 'Lot name', 'sell.artist': 'Artist / Event', 'sell.type': 'Lot type', 'sell.description': 'Description',
    'sell.startPrice': 'Starting price', 'sell.bidStep': 'Bid step', 'sell.priceCurrency': 'Price currency',
    'sell.concertDate': 'Concert date', 'sell.duration': 'Auction duration',
    'sell.dur1h': '1 hour (test)', 'sell.dur24h': '24 hours', 'sell.dur2d': '2 days', 'sell.dur3d': '3 days', 'sell.dur1w': '1 week', 'sell.dur2w': '2 weeks', 'sell.durCustom': 'Custom…',
    'sell.feature': 'Feature on top', 'sell.featureBody': 'The lot is shown at the top of the catalogue with a Featured badge. Attracts 3–5× more bids.',
    'sell.publish': 'Publish',
    'sell.yourBalance': 'Your balance', 'sell.inEscrow': '🔒 In escrow', 'sell.escrowHint': 'Released after buyers confirm delivery',
    'sell.topup': 'Top up',
    'sell.myAuctions': 'My auctions', 'sell.lotHistory': 'Lot history', 'sell.fees': 'Fees',
    'sell.escrowSection': '🔒 Escrow', 'sell.escrowDeals': 'Deals in progress',
    'sell.escrowDealsHint': 'Send the ticket to the buyer. Funds land on your balance once they confirm.',
    'profile.awaitsPayment': 'Awaiting payment',
    'profile.youWon': 'You won · pay the winning bid',
    'profile.notPaidNote': 'If not paid in time, the lot moves to the next bidder.',
    'profile.payCard': 'Pay by card',
    'profile.payBalance': 'Pay from balance',
  },
  hy: {
    'nav.home': 'Գլխավոր',
    'nav.active': 'Ակտիվ աճուրդներ',
    'nav.how': 'Ինչպես է աշխատում',
    'nav.hall': '🏆 Փառքի սրահ',
    'nav.sell': '+ Վաճառել',
    'nav.profile': 'Պրոֆիլ',
    'nav.chats': 'Չաթեր',
    'header.online': 'օնլայն',
    'header.login': 'Մուտք',
    'header.signup': 'Գրանցվել',
    'header.logout': 'Ելք',
    'badge.live': 'ընթացիկ',
    'badge.endingSoon': '⏰ շուտով ավարտ',
    'badge.finalHour': 'Վերջին ժամը',
    'badge.reserveMet': 'Ռեզերվն անցել է',
    'status.active': 'Ընթացիկ',
    'status.ended': 'Ավարտված',
    'status.upcoming': 'Շուտով',
    'time.endsIn': 'Մինչ ավարտ',
    'time.lessHour': 'Քիչ քան մեկ ժամ',
    'time.ended': 'Ավարտված',
    'time.soon': 'Շուտով',
    'lot.bid': 'Կատարել առաջարկ',
    'lot.currentBid': 'Ընթացիկ առաջարկ',
    'lot.step': 'Քայլ',
    'lot.type.tickets': 'Տոմսեր',
    'lot.type.vip': 'VIP անցաթուղթ',
    'lot.type.table': 'Սեղան',
    'lot.bidsActive': 'ակտիվ առաջարկ',
    'lot.totalBids': 'ընդամենը առաջարկներ',
    'lot.verified': 'հաստատված',
    'lot.bidders': 'առաջարկողներ',
    'lot.history': 'Առաջարկների պատմություն',
    'lot.activity': 'Ակտիվություն',
    'lot.last': 'վերջին',
    'lot.bidsCount': 'առաջարկ',
    'lot.minBid': 'Առաջարկ-ից',
    'lot.feed': '📡 Կենդանի հոսք',
    'lot.podium': '🏆 Պատվանդան',
    'lot.share': 'Կիսվել',
    'lot.rules': 'Կանոններ',
    'lot.timer': 'Մինչ ավարտ',
    'lot.startPrice': 'Մեկնարկային',
    'lot.minimum': 'Նվազագույն',
    'lot.growth': 'Աճ',
    'lot.concertDate': 'Համերգի ամսաթիվ',
    'lot.endTime': 'Աճուրդի ավարտ',
    'lot.duration': 'Տևողություն',
    'lot.description': 'Նկարագրություն',
    'lot.viewers': 'դիտում են',
    'common.cancel': 'Չեղարկել',
    'common.confirm': 'Հաստատել',
    'common.networkError': 'Ցանցի սխալ',
    'common.loading': 'Բեռնում...',
    'common.back': 'Վերադառնալ կատալոգ',
    'common.activity': 'Ակտիվություն',
    'bid.tooLow': 'Գումարը նվազագույնից փոքր է',
    'bid.duplicate': 'Կրկնված առաջարկ',
    'bid.lotEnded': 'Աճուրդն ավարտվել է',
    'bid.notActive': 'Աճուրդն ակտիվ չէ',
    'bid.invalidShareUrl': 'Տեղադրեք գրառման հղումը',
    'bid.shareIsNotPost': 'Սա կիսման պատուհանի հղում է, ոչ թե գրառման: Բացեք ձեր VK պրոֆիլը և պատճենեք գրառման URL-ը:',
    'bid.insufficientFunds': 'Բավարար միջոցներ չկան այս առաջարկի համար',
    'bid.minimum': 'Նվազագույն առաջարկ',
    'sell.feeListing': 'Ցուցակագրում',
    'sell.feeFeatured': 'Բարձրացնել',
    'sell.publish': 'Հրապարակել',
    'profile.balance': 'Մնացորդ',
    'profile.balanceNote': 'USD · փոխարկվում է վճարման ժամանակ',
    'profile.activity': 'Ակտիվություն',
    'profile.myBids': 'Իմ առաջարկները',
    'profile.topup': 'Համալրում',
    'profile.topupBtn': 'Համալրել',
    'profile.topupHint': '«Քարտով»-ը անմիջապես կհանի լռելյայն քարտից:',
    'profile.providerCard': 'Քարտով',
    'profile.providerDemo': 'Դեմո',
    'profile.settingsTitle': 'Կարգավորումներ',
    'profile.settingsSubtitle': 'Արժույթ և լեզու',
    'profile.currency': 'Ցուցադրման արժույթ',
    'profile.currencyHint': 'Կկիրառվի ամբողջ կայքում:',
    'profile.language': 'Լեզու',
    'profile.languageHint': 'Թարգմանում է ինտերֆեյսը: Լոտերի անվանումներն ու նկարագրությունները թարգմանվում են էջի բեռնման ժամանակ:',
    'profile.cards': 'Քարտեր',
    'profile.cardsTitle': 'Վճարման մեթոդներ',
    'profile.cardsHint': 'Հաղթելու դեպքում գումարը կհանվի լռելյայն քարտից:',
    'profile.addCard': 'Կցել քարտ',
    'profile.watchlist': 'Հետևում եմ լոտերին',
    'profile.favorites': 'Ընտրված',
    'profile.history': 'Գնումների պատմություն',
    'profile.escrow': 'Էսքրոու և վճարումներ',
    'profile.escrowHint': 'Գումարը պահվում է էսքրոուում մինչև տոմս ստանալու հաստատումը:',
    'profile.confirmDelivery': 'Հաստատել ստացումը և ազատել գումարը',
    'profile.profile': 'Պրոֆիլ',
    'hero.premium': 'ՊՐԵՄԻՈՒՄ',
    'hero.auction': 'ԱՃՈՒՐԴ',
    'hero.subtitle': 'Համերգային լոտեր, VIP սեղաններ և բեքսթեյջ պահեր՝ իրական ժամանակում աճուրդի ձևաչափով: Որպեսզի առաջարկը ուժի մեջ մտնի, կիսվեք լոտով սոցցանցում:',
    'catalog.hotTitle': '🔥 Թեժ լոտեր',
    'catalog.hotSubtitle': 'Շուտով ավարտ',
    'catalog.topTitle': '⭐ Թոփ',
    'catalog.topSubtitle': 'Առաջխաղացված աճուրդներ',
    'catalog.topTitle': '⭐ Թոփ',
    'catalog.topSubtitle': 'Առաջատար աճուրդներ',
    'catalog.title': 'Կատալոգ',
    'catalog.subtitle': 'Համերգային լոտեր',
    'filter.active': 'Ընթացիկ',
    'filter.ended': 'Ավարտված',
    'filter.upcoming': 'Շուտով',
    'modal.terminal': 'Առաջարկ',
    'modal.minimum': 'Նվազ.',
    'modal.continue': 'Շարունակել',
    'modal.manual': 'Ձեռքով',
    'modal.autobid': '⚡ Ավտոառաջարկ',
    'modal.autobidHint': '⚡ Ավտոառաջարկ. համակարգն ավտոմատ բարձրացնում է մինչև այս գումարը.',
    'modal.bidAmount': 'Առաջարկի գումար',
    'modal.plus1step': '+1 քայլ',
    'modal.plus3steps': '+3 քայլ',
    'modal.plus5steps': '+5 քայլ',
    'chat.title': '💬 Չատ վաճառողի հետ',
    'chat.loading': 'Բեռնում...',
    'sell.image': 'Լոտի նկար',
    'sell.imageDrop': 'Տեղադրեք նկարը կամ սեղմեք',
    'sell.imageHint': 'JPG, PNG, WebP կամ GIF մինչև 6 ՄԲ. Ոչ պարտադիր.',
    'lot.activityHourly': 'Ժամային ակտիվություն',
    'lot.hours': 'ժ',
    'rules.minBid': 'Նվազագույն առաջարկ',
    'rules.share': 'Կիսվեք լոտով VK/FB-ում',
    'rules.keepPost': 'Մի ջնջեք գրառումը մինչ վերջ',
    'rules.payIn24h': 'Վճարեք շահումը 24 ժամում',
    'hall.eyebrow': '🏆 Փառքի սրահ',
    'hall.title': 'Փառքի սրահ',
    'hall.subtitle': 'Լավագույն լոտերը, ամենահամառ առաջարկողները և լեգենդար ճակատամարտերը:',
    'hall.mostExpensive': '💎 Ամենաթանկը',
    'hall.hardestBattle': '⚔️ Ամենադաժան ճակատամարտը',
    'hall.biggestGrowth': '📈 Առավելագույն աճ',
    'hall.topBuyer': '👑 Թագավոր գնորդ',
    'hall.topSeller': '⭐ Թոփ վաճառող',
    'hall.mostPersistent': '🔥 Ամենահամառը',
    'hall.openLot': 'Բացել լոտը',
    'hall.bidsMade': 'առաջարկ արված է',
    'hall.wins': 'հաղթանակ',
    'hall.totalSpent': 'ընդհանուր ծախսը',
    'hall.profile': 'վաճառողի պրոֆիլ',
    'hall.soldLots': 'վաճառված լոտեր',
    'hall.neverGivesUp': 'երբեք չի հանձնվում',
    'hall.totalBidsAllTime': 'առաջարկ ընդհանուր',
    'hall.joinAuction': 'Մասնակցել աճուրդին',
    'how.back': 'Վերադառնալ գլխավոր',
    'how.eyebrow': 'Ուղեցույց',
    'how.title': 'Ինչպես է աշխատում BidStage-ը',
    'how.subtitle': 'Համերգային լոտերի աճուրդ՝ ինչքան բարձր է առաջարկը, այնքան մոտ եք տոմսին: Որպեսզի առաջարկը հաշվի առնվի, պետք է կիսվել լոտով սոցցանցում:',
    'how.start': 'Մեկնարկ', 'how.bid': 'Առաջարկ', 'how.share': 'Կիսում', 'how.timer': 'Ժամանակաչափ', 'how.win': 'Հաղթանակ', 'how.ticket': 'Տոմս',
    'how.s1.title': '01 — Գրանցում', 'how.s1.body': 'Ստեղծեք հաշիվ էլ. փոստով կամ դեմո օգտվող: Կցեք քարտ պրոֆիլում ակնթարթային վճարման համար:',
    'how.s2.title': '02 — Կատարեք առաջարկ', 'how.s2.body': 'Նվազագույնը՝ ընթացիկ գին գումարած քայլ: Հասանելի է ավտոառաջարկ՝ սահմանեք առավելագույնը, համակարգը ինքն է գերազանցում:',
    'how.s3.title': '03 — Կիսվեք լոտով', 'how.s3.body': 'Հրապարակեք գրառում VK կամ FB-ում և ուղարկեք գրառման հղումը: Համակարգն ինքն է ստուգում:',
    'how.s4.title': '04 — Հակասնայպինգ', 'how.s4.body': 'Վերջին 3 րոպեի առաջարկն ավտոմատ երկարաձգում է աճուրդը 180 վրկ-ով:',
    'how.s5.title': '05 — Վճարում', 'how.s5.body': 'Հաղթողը վճարում է քարտով 24 ժամում: Չվճարելու դեպքում լոտը անցնում է հաջորդ առաջարկողին:',
    'how.s6.title': '06 — Թվային տոմս', 'how.s6.body': 'Վճարումից հետո ստանում եք 32-նիշանոց եզակի կոդ: Գումարը էսքրոուում է մինչև առաքման հաստատումը:',
    'how.protectBuyer': 'Գնորդի պաշտպանություն',
    'how.protectBuyerBody': 'Գումարը պահվում է էսքրոուում: Վաճառողը կստանա միայն ձեր հաստատումից հետո:',
    'how.protectSeller': 'Վաճառողի պաշտպանություն',
    'how.protectSellerBody': 'Յուրաքանչյուր առաջարկ ապահովված է կիսման պարտադիր ստուգմամբ VK API-ով:',
    'how.cascade': 'Վճարման կասկադ',
    'how.cascadeBody': 'Եթե հաղթողը չվճարի, լոտը անցնում է հաջորդին: Չվճարող դեպքում նոր ցուցակագրում:',
    'how.fees': 'Վաճառողի վճարներ', 'how.feeListing': 'Ցուցակագրում', 'how.feeFeatured': 'Բարձրացում (Featured)', 'how.feeFinal': 'Վերջնական վճար',
    'how.feesNote': 'Չվաճառվելու դեպքում ցուցակագրման վճարը չի վերադարձվում, բայց վերջնական վճարը չի գանձվում:',
    'how.providers': 'Վճարման մատակարարներ', 'how.armenia': 'Հայաստան', 'how.russia': 'Ռուսաստան', 'how.world': 'Այլ երկրներ',
    'how.providerNote': 'Համակարգն ինքնաբերաբար ընտրում է մատակարարը ձեր պրոֆիլի երկրի հիման վրա:',
    'how.toHome': 'Գլխավոր', 'how.signup': 'Ստեղծել հաշիվ', 'how.listLot': 'Ավելացնել լոտ',
    'sell.newLot': 'Նոր լոտ', 'sell.paidListing': 'Վճարովի ցուցակագրում',
    'sell.createTitle': 'Ստեղծել աճուրդ',
    'sell.createSubtitle': 'Հանեք ձեր լոտը աճուրդի: Հարթակը գանձում է ցուցակագրման վճար և տոկոս վաճառքից:',
    'sell.lotName': 'Լոտի անուն', 'sell.artist': 'Արտիստ / Իրադարձություն', 'sell.type': 'Լոտի տեսակ', 'sell.description': 'Նկարագրություն',
    'sell.startPrice': 'Մեկնարկային գին', 'sell.bidStep': 'Առաջարկի քայլ', 'sell.priceCurrency': 'Գնի արժույթ',
    'sell.concertDate': 'Համերգի ամսաթիվ', 'sell.duration': 'Աճուրդի տևողություն',
    'sell.dur1h': '1 ժամ (թեստ)', 'sell.dur24h': '24 ժամ', 'sell.dur2d': '2 օր', 'sell.dur3d': '3 օր', 'sell.dur1w': '1 շաբաթ', 'sell.dur2w': '2 շաբաթ', 'sell.durCustom': 'Սեփական…',
    'sell.feature': 'Բարձրացնել', 'sell.featureBody': 'Լոտը ցուցադրվում է կատալոգի սկզբում Featured նշանով: Գրավում է 3–5× ավելի առաջարկներ:',
    'sell.publish': 'Հրապարակել',
    'sell.yourBalance': 'Ձեր մնացորդը', 'sell.inEscrow': '🔒 Էսքրոուում', 'sell.escrowHint': 'Կհաշվեգրվի գնորդների հաստատումից հետո',
    'sell.topup': 'Համալրել',
    'sell.myAuctions': 'Իմ աճուրդները', 'sell.lotHistory': 'Լոտերի պատմություն', 'sell.fees': 'Վճարներ',
    'sell.escrowSection': '🔒 Էսքրոու', 'sell.escrowDeals': 'Ընթացիկ գործարքներ',
    'sell.escrowDealsHint': 'Ուղարկեք տոմսը գնորդին: Գումարը կհաշվեգրվի մնացորդին հաստատումից հետո:',
    'profile.awaitsPayment': 'Սպասում է վճարման',
    'profile.youWon': 'Դուք հաղթեցիք · վճարեք',
    'profile.notPaidNote': 'Չվճարելու դեպքում լոտը կփոխանցվի հաջորդ առաջարկողին:',
    'profile.payCard': 'Վճարել քարտով',
    'profile.payBalance': 'Հանել մնացորդից',
  },
};

function t(key) {
  return (I18N[currentLang] && I18N[currentLang][key]) || (I18N.ru[key]) || key;
}

function applyLanguage() {
  document.documentElement.setAttribute('lang', currentLang);
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const translated = t(key);
    if (translated && translated !== key) el.textContent = translated;
  });
  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('seg-btn-active', btn.dataset.lang === currentLang);
  });
  translateContent();
}

const translationCache = {};
let translateScheduled = false;

function translateContent() {
  if (translateScheduled) return;
  translateScheduled = true;
  setTimeout(() => {
    translateScheduled = false;
    runTranslate();
  }, 80);
}

function runTranslate() {
  const nodes = Array.from(document.querySelectorAll('[data-translate]'));
  if (!nodes.length) return;
  if (currentLang === 'ru') {
    nodes.forEach((n) => {
      if (n.dataset.originalText) n.textContent = n.dataset.originalText;
    });
    return;
  }
  const requests = [];
  const requestNodes = [];
  nodes.forEach((n) => {
    const original = n.dataset.originalText || n.textContent.trim();
    n.dataset.originalText = original;
    if (!original) return;
    const cacheKey = currentLang + '|' + original;
    if (translationCache[cacheKey]) {
      n.textContent = translationCache[cacheKey];
      return;
    }
    requests.push(original);
    requestNodes.push({ node: n, original, cacheKey });
  });
  if (!requests.length) return;
  fetch('/api/translate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ lang: currentLang, items: requests }),
  })
    .then((r) => (r.ok ? r.json() : null))
    .then((data) => {
      if (!data || !Array.isArray(data.items)) return;
      data.items.forEach((translated, i) => {
        const entry = requestNodes[i];
        if (!entry) return;
        translationCache[entry.cacheKey] = translated;
        if (entry.node.isConnected) entry.node.textContent = translated;
      });
    })
    .catch(() => {});
}

const formatMoney = (amountUsd, currency) => {
  const value = Number(amountUsd) * (rates[currency] || 1);
  const digits = fractionDigits[currency] != null ? fractionDigits[currency] : 0;
  const formatted = new Intl.NumberFormat('ru-RU', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value);
  if (currency === 'USD') return symbols[currency] + formatted;
  return formatted + ' ' + symbols[currency];
};

const updatePrices = () => {
  document.querySelectorAll('.price[data-price-usd], span[data-price-usd], p[data-price-usd]').forEach((el) => {
    if (el.tagName === 'A' || el.classList.contains('lot-card')) return;
    if (el.children.length > 0) return;
    const usd = Number(el.dataset.priceUsd);
    if (!Number.isFinite(usd)) return;
    el.textContent = formatMoney(usd, currentCurrency);
  });
  document.querySelectorAll('[data-price-amd]').forEach((card) => {
    const amd = Number(card.dataset.priceAmd);
    if (!amd) return;
    const usdEquivalent = amd / (rates.AMD || 390);
    card.querySelectorAll('.price').forEach((el) => {
      if (el.children.length > 0) return;
      el.textContent = formatMoney(usdEquivalent, currentCurrency);
    });
  });
  document.querySelectorAll('[data-step-amd]').forEach((card) => {
    const stepAmd = Number(card.dataset.stepAmd);
    if (!stepAmd) return;
    const stepUsd = stepAmd / (rates.AMD || 390);
    card.querySelectorAll('[data-step-display]').forEach((el) => {
      el.textContent = formatMoney(stepUsd, currentCurrency);
    });
  });
  document.querySelectorAll('[data-balance-display]').forEach((balEl) => {
    if (balEl.dataset.balanceUsd != null) {
      balEl.textContent = formatMoney(Number(balEl.dataset.balanceUsd), currentCurrency);
    }
  });
};

const setCurrency = (currency) => {
  currentCurrency = currency;
  window.currentCurrency = currency;
  localStorage.setItem('bs.currency', currency);
  document.querySelectorAll('.currency-btn').forEach((btn) => {
    btn.classList.toggle('seg-btn-active', btn.dataset.currency === currency);
  });
  updatePrices();
  if (typeof refreshBidUnit === 'function' && selectedLot) {
    const oldUsd = bidInputToUsd(bidAmount && bidAmount.dataset.lastInput || 0);
    refreshBidUnit();
    if (bidAmount) {
      const cur = getBidUnit();
      const v = usdToBidInput(oldUsd || getMinUsd());
      bidAmount.value = String((cur === 'USD') ? Math.round(v * 100) / 100 : Math.round(v));
      updateBidPreview();
    }
  }
};

const setLanguage = (lang) => {
  currentLang = lang;
  localStorage.setItem('bs.lang', lang);
  applyLanguage();
};

document.querySelectorAll('.currency-btn').forEach((btn) => {
  btn.addEventListener('click', () => setCurrency(btn.dataset.currency));
});
document.querySelectorAll('.lang-btn').forEach((btn) => {
  btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
});

function renderLotCard(lot, idx) {
  const card = document.createElement('a');
  card.href = '/lot/' + lot.id;
  card.className = 'lot-card group block';
  card.dataset.lotId = String(lot.id);
  card.dataset.status = lot.status || 'active';
  card.dataset.priceAmd = String(lot.current_price_amd || 0);
  card.dataset.endOffset = String(lot.end_offset_seconds || 0);
  card.dataset.endTs = String(lot.end_ts_ms || (Date.now() + (lot.end_offset_seconds || 0) * 1000));
  card.dataset.stepAmd = String(lot.step_amd || 0);
  card.dataset.name = lot.title || '';
  const cover = document.createElement('div');
  cover.className = 'lot-cover lot-cover-grad-' + (idx % 4) + (lot.image_url ? ' has-image' : '');
  if (lot.image_url) {
    const img = document.createElement('img');
    img.src = lot.image_url;
    img.alt = lot.title || '';
    img.loading = 'lazy';
    img.className = 'lot-cover-img';
    img.addEventListener('error', () => img.remove());
    cover.appendChild(img);
  }
  const fade = document.createElement('div');
  fade.className = 'lot-cover-fade';
  cover.appendChild(fade);
  const pills = document.createElement('div');
  pills.className = 'lot-cover-pills';
  const idPill = document.createElement('span');
  idPill.className = 'pill';
  idPill.textContent = '#' + lot.id;
  pills.appendChild(idPill);
  if (lot.status === 'ended') {
    const ep = document.createElement('span');
    ep.className = 'pill pill-muted';
    ep.textContent = t('status.ended');
    pills.appendChild(ep);
  } else if (lot.status === 'cancelled') {
    const ep = document.createElement('span');
    ep.className = 'pill pill-muted';
    ep.textContent = 'Отменён';
    pills.appendChild(ep);
  }
  cover.appendChild(pills);
  const foot = document.createElement('div');
  foot.className = 'lot-cover-foot';
  const t1 = document.createElement('p');
  t1.className = 'lot-cover-title';
  t1.dataset.translate = '';
  t1.textContent = lot.title || '';
  const t2 = document.createElement('p');
  t2.className = 'lot-cover-artist';
  t2.dataset.translate = '';
  t2.textContent = lot.artist || '';
  foot.appendChild(t1);
  foot.appendChild(t2);
  cover.appendChild(foot);
  card.appendChild(cover);
  const meta = document.createElement('div');
  meta.className = 'px-1 mt-3';
  meta.innerHTML = '<div class="flex items-center justify-between"><div><p class="text-xs uppercase tracking-wider text-muted">Ставка</p><p class="price text-lg font-bold text-violet" data-price-usd="' + (lot.current_price_usd_value || 0).toFixed(2) + '">$' + (lot.current_price_usd_value || 0).toFixed(2) + '</p></div><div class="text-right"><p class="text-xs uppercase tracking-wider text-muted">' + (lot.status === 'ended' ? 'Завершён' : 'До конца') + '</p><p class="timer font-mono text-base font-bold tabular-nums" data-text="' + (lot.status === 'ended' ? t('time.ended') : '00:00:00') + '">' + (lot.status === 'ended' ? t('time.ended') : '00:00:00') + '</p></div></div>';
  card.appendChild(meta);
  if (lot.status === 'active' && lot.end_ts_ms) {
    card.dataset.targetTime = String(lot.end_ts_ms);
  }
  return card;
}

const filterLots = async (status) => {
  document.querySelectorAll('.filter-btn').forEach((btn) => {
    btn.classList.toggle('seg-btn-active', btn.dataset.filter === status);
  });
  const grid = document.getElementById('lot-grid');
  if (!grid) return;
  grid.dataset.currentFilter = status;
  grid.innerHTML = '<div class="col-span-full text-center py-12 text-muted">Загрузка…</div>';
  try {
    const resp = await fetch('/api/lots?status=' + encodeURIComponent(status));
    const data = await resp.json();
    grid.innerHTML = '';
    const lots = (data && data.lots) || [];
    if (lots.length === 0) {
      const msgs = {
        active: 'Активных аукционов сейчас нет',
        ended: 'Завершённых аукционов пока нет',
        upcoming: 'Предстоящих аукционов пока нет',
      };
      const empty = document.createElement('div');
      empty.className = 'col-span-full cyber-card p-8 text-center';
      empty.innerHTML = '<iconify-icon icon="lucide:inbox" class="text-3xl text-muted"></iconify-icon><p class="mt-3 text-base font-bold">' + (msgs[status] || 'Ничего не найдено') + '</p>';
      grid.appendChild(empty);
      return;
    }
    lots.forEach((lot, i) => grid.appendChild(renderLotCard(lot, i)));
    if (typeof updateTimers === 'function') updateTimers();
    if (typeof updatePrices === 'function') updatePrices();
    if (typeof translateContent === 'function') translateContent();
  } catch (e) {
    grid.innerHTML = '<div class="col-span-full text-center py-12 text-muted">Ошибка загрузки</div>';
  }
};

document.querySelectorAll('.filter-btn').forEach((btn) => {
  btn.addEventListener('click', () => filterLots(btn.dataset.filter));
});

const now = Date.now();
document.querySelectorAll('[data-lot-id]').forEach((card) => {
  if (card.dataset.endTs) {
    card.dataset.targetTime = card.dataset.endTs;
  } else if (card.dataset.endOffset) {
    card.dataset.targetTime = now + Number(card.dataset.endOffset) * 1000;
  }
  if (card.dataset.startOffset) card.dataset.targetTime = now + Number(card.dataset.startOffset) * 1000;
});

const formatDuration = (ms) => {
  const total = Math.max(0, Math.floor(ms / 1000));
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  if (days > 0) return `${days}д ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  return [hours, minutes, seconds].map((p) => String(p).padStart(2, '0')).join(':');
};

const updateTimers = () => {
  const nowMs = Date.now();
  document.querySelectorAll('[data-lot-id]').forEach((card) => {
    const timer = card.querySelector('.timer');
    if (!timer || !card.dataset.targetTime) return;
    const remaining = Number(card.dataset.targetTime) - nowMs;
    if (card.dataset.status === 'ended' || (remaining <= 0 && card.dataset.status === 'active')) {
      timer.textContent = t('time.ended');
      timer.dataset.text = t('time.ended');
      card.dataset.endClass = 'ended';
      const grid = document.getElementById('lot-grid');
      const inGrid = card.closest('#lot-grid');
      const currentFilter = grid && grid.dataset && grid.dataset.currentFilter;
      if (inGrid && currentFilter !== 'ended') card.style.display = 'none';
      return;
    }
    const value = formatDuration(remaining);
    if (timer.textContent !== value) {
      timer.textContent = value;
      timer.dataset.text = value;
    }
    if (remaining < 60_000 && remaining > 0) {
      timer.classList.add('timer-final-min');
      card.dataset.endClass = 'critical';
    } else if (remaining < 10 * 60_000) {
      timer.classList.remove('timer-final-min');
      card.dataset.endClass = 'critical';
    } else if (remaining < 3600_000) {
      timer.classList.remove('timer-final-min');
      card.dataset.endClass = 'warn';
    } else {
      timer.classList.remove('timer-final-min');
      card.dataset.endClass = '';
    }
  });
};

const formPersist = (() => {
  const STORAGE_PREFIX = 'bs.form.';
  function key(form) {
    return STORAGE_PREFIX + (form.id || form.getAttribute('name') || form.action || 'unknown');
  }
  function snapshot(form) {
    const data = {};
    form.querySelectorAll('input, select, textarea').forEach((el) => {
      if (!el.name && !el.id) return;
      if (el.type === 'password' || el.type === 'file' || el.type === 'submit' || el.type === 'button') return;
      const id = el.name || el.id;
      if (el.type === 'checkbox' || el.type === 'radio') data[id] = el.checked;
      else data[id] = el.value;
    });
    return data;
  }
  function restore(form) {
    let raw;
    try { raw = localStorage.getItem(key(form)); } catch (e) { return; }
    if (!raw) return;
    let data;
    try { data = JSON.parse(raw); } catch (e) { return; }
    form.querySelectorAll('input, select, textarea').forEach((el) => {
      const id = el.name || el.id;
      if (!id || !(id in data)) return;
      if (el.type === 'password' || el.type === 'file') return;
      if (el.type === 'checkbox' || el.type === 'radio') el.checked = !!data[id];
      else el.value = data[id];
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }
  function save(form) {
    try { localStorage.setItem(key(form), JSON.stringify(snapshot(form))); } catch (e) { /* quota */ }
  }
  function clear(form) {
    try { localStorage.removeItem(key(form)); } catch (e) { /* noop */ }
  }
  function attach(form) {
    if (!form || form.dataset.persistAttached === '1') return;
    form.dataset.persistAttached = '1';
    if (!form.dataset.noRestore) restore(form);
    form.addEventListener('input', () => save(form));
    form.addEventListener('change', () => save(form));
    form.addEventListener('submit', () => clear(form));
  }
  return { attach, clear, save, restore };
})();

document.querySelectorAll('form[data-persist]').forEach((form) => formPersist.attach(form));

const modal = document.getElementById('bid-modal');
const bidAmount = modal ? document.getElementById('bid-amount') : null;
const minimumBid = modal ? document.getElementById('minimum-bid') : null;
const amdPreview = modal ? document.getElementById('amd-preview') : null;
const rubPreview = modal ? document.getElementById('rub-preview') : null;
const usdPreview = modal ? document.getElementById('usd-preview') : null;
const modalTitle = modal ? document.getElementById('modal-title') : null;
const stepNodes = modal ? Array.from(document.querySelectorAll('.modal-step')) : [];
const indicators = modal ? Array.from(document.querySelectorAll('.step-indicator')) : [];

const showStep = (index) => {
  stepNodes.forEach((step, i) => step.classList.toggle('step-inactive', i !== index));
  indicators.forEach((ind, i) => {
    ind.classList.toggle('pill-violet', i <= index);
    ind.classList.toggle('pill-muted', i > index);
    ind.style.cursor = i < index ? 'pointer' : '';
  });
};
window.showStep = showStep;

indicators.forEach((ind, i) => {
  ind.addEventListener('click', () => {
    const activeIdx = indicators.findIndex((el) => el.classList.contains('pill-violet') && (indicators.indexOf(el) === indicators.length - 1 || !indicators[indicators.indexOf(el) + 1].classList.contains('pill-violet')));
    if (i <= activeIdx) showStep(i);
  });
});

function getBidUnit() {
  return currentCurrency || 'USD';
}

function bidInputToUsd(amount) {
  const cur = getBidUnit();
  if (cur === 'USD') return Number(amount) || 0;
  const rate = rates[cur] || 1;
  return (Number(amount) || 0) / rate;
}

function usdToBidInput(amountUsd) {
  const cur = getBidUnit();
  if (cur === 'USD') return Number(amountUsd) || 0;
  const rate = rates[cur] || 1;
  return (Number(amountUsd) || 0) * rate;
}

function getMinUsd() {
  if (!selectedLot) return 0;
  if (selectedLot.dataset.minUsd != null) return Number(selectedLot.dataset.minUsd);
  const priceUsd = Number(selectedLot.dataset.priceUsd || 0);
  const stepUsd = Number(selectedLot.dataset.stepUsd || 0);
  if (priceUsd > 0 && stepUsd > 0) return priceUsd + stepUsd;
  const priceAmd = Number(selectedLot.dataset.priceAmd || 0);
  const stepAmd = Number(selectedLot.dataset.stepAmd || 0);
  return (priceAmd + stepAmd) / (rates.AMD || 390);
}

function getStepUsd() {
  if (!selectedLot) return 0;
  if (selectedLot.dataset.stepUsd != null) return Number(selectedLot.dataset.stepUsd);
  const stepAmd = Number(selectedLot.dataset.stepAmd || 0);
  return stepAmd / (rates.AMD || 390);
}

const MAX_BID_USD = 1000000; // совпадает с сервером

const updateBidPreview = () => {
  if (!bidAmount) return;
  const amountInCurrent = Number(bidAmount.value || 0);
  const amountUsd = bidInputToUsd(amountInCurrent);
  const amdRate = rates.AMD || 390;
  const rubRate = rates.RUB || 90;
  const amdText = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 0 }).format(amountUsd * amdRate);
  const rubText = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 0 }).format(amountUsd * rubRate);
  const usdText = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(amountUsd);
  if (amdPreview) { amdPreview.textContent = amdText; amdPreview.title = amdText + ' AMD'; }
  if (rubPreview) { rubPreview.textContent = rubText; rubPreview.title = rubText + ' RUB'; }
  if (usdPreview) { usdPreview.textContent = usdText; usdPreview.title = '$' + usdText; }
  validateBidStep1();
};

function showStep1Error(msg) {
  let el = document.getElementById('step1-error');
  if (!el && bidAmount) {
    el = document.createElement('p');
    el.id = 'step1-error';
    el.className = 'mt-2 text-sm font-semibold';
    el.style.color = 'var(--danger)';
    bidAmount.parentNode.parentNode.insertBefore(el, document.getElementById('continue-share'));
  }
  if (el) {
    el.textContent = msg;
    el.style.display = msg ? 'block' : 'none';
  }
}

function getBalanceUsd() {
  const el = document.querySelector('[data-balance-display]');
  if (el && el.dataset.balanceUsd != null) return Number(el.dataset.balanceUsd);
  return null;
}

function validateBidStep1() {
  if (!bidAmount || !selectedLot) return true;
  const amountUsd = bidInputToUsd(bidAmount.value);
  const minUsd = getMinUsd();
  const continueBtn = document.getElementById('continue-share');
  if (amountUsd < minUsd - 0.001) {
    showStep1Error(t('bid.tooLow') + ': ' + formatMoney(minUsd, currentCurrency));
    if (continueBtn) continueBtn.disabled = true;
    return false;
  }
  if (amountUsd > MAX_BID_USD + 0.001) {
    showStep1Error('Максимум ' + formatMoney(MAX_BID_USD, currentCurrency));
    if (continueBtn) continueBtn.disabled = true;
    return false;
  }
  const balance = getBalanceUsd();
  if (balance !== null && amountUsd > balance + 0.001) {
    showStep1Error(t('bid.insufficientFunds') + ': ' + formatMoney(balance, currentCurrency));
    if (continueBtn) continueBtn.disabled = true;
    return false;
  }
  showStep1Error('');
  if (continueBtn) continueBtn.disabled = false;
  return true;
}

function refreshBidUnit() {
  const unit = document.getElementById('bid-amount-unit');
  if (unit) unit.textContent = getBidUnit();
  if (bidAmount && selectedLot) {
    const minDisplay = document.querySelector('[data-min-display]');
    const minUsd = getMinUsd();
    if (minDisplay) minDisplay.textContent = formatMoney(minUsd, currentCurrency);
    if (minimumBid) minimumBid.textContent = t('bid.minimum') + ': ' + formatMoney(minUsd, currentCurrency);
  }
}

const openModal = (card) => {
  if (!modal) return;
  selectedLot = card;
  if (modalTitle) modalTitle.textContent = card.dataset.name;
  const minUsd = getMinUsd();
  if (bidAmount) {
    const inputMin = usdToBidInput(minUsd);
    const cur = getBidUnit();
    const decimals = (cur === 'USD') ? 2 : 0;
    const rounded = decimals === 0 ? Math.ceil(inputMin) : Math.ceil(inputMin * 100) / 100;
    bidAmount.min = rounded;
    bidAmount.step = (cur === 'USD') ? '0.5' : (cur === 'RUB' ? '10' : '100');
    bidAmount.value = String(rounded);
  }
  refreshBidUnit();
  updateBidPreview();
  showStep(0);
  modal.classList.add('is-open');
};

const closeModal = () => {
  if (!modal) return;
  modal.classList.remove('is-open');
};

document.querySelectorAll('.open-bid-modal').forEach((button) => {
  button.addEventListener('click', (event) => {
    event.preventDefault();
    const card = event.currentTarget.closest('[data-lot-id]')
      || document.querySelector('article[data-lot-id]')
      || document.querySelector('[data-lot-id]');
    if (card) openModal(card);
  });
});

document.querySelectorAll('.quick-bid').forEach((btn) => {
  btn.addEventListener('click', () => {
    if (!bidAmount || !selectedLot) return;
    const steps = Number(btn.dataset.steps) || 1;
    const stepUsd = getStepUsd();
    const minUsd = getMinUsd();
    let targetUsd = minUsd + (steps - 1) * stepUsd;
    if (targetUsd > MAX_BID_USD) targetUsd = MAX_BID_USD;
    const inputValue = usdToBidInput(targetUsd);
    const cur = getBidUnit();
    const rounded = (cur === 'USD') ? Math.ceil(inputValue * 100) / 100 : Math.ceil(inputValue);
    bidAmount.value = String(rounded);
    updateBidPreview();
  });
});

if (bidAmount) bidAmount.addEventListener('input', () => {
  // Жёсткий клиент-сайд лимит длины (защита от вставки 21-значного числа)
  if (bidAmount.value && bidAmount.value.length > 14) {
    bidAmount.value = bidAmount.value.slice(0, 14);
  }
  updateBidPreview();
});

const continueShareBtn = document.getElementById('continue-share');
if (continueShareBtn) continueShareBtn.addEventListener('click', () => {
  if (!validateBidStep1()) return;
  showStep(1);
});

function showShareError(msg) {
  const el = document.getElementById('share-error');
  if (el) {
    el.textContent = msg;
    el.classList.remove('hidden');
  }
}
function hideShareError() {
  const el = document.getElementById('share-error');
  if (el) el.classList.add('hidden');
}

let pendingBidPayload = null;

function showOtpError(msg) {
  const el = document.getElementById('otp-error');
  if (el) {
    el.textContent = msg;
    el.classList.toggle('hidden', !msg);
  }
}

async function submitBid(payload) {
  const resp = await fetch('/api/bid', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return resp;
}

const confirmBidBtn = document.getElementById('confirm-bid');
if (confirmBidBtn) confirmBidBtn.addEventListener('click', async () => {
  hideShareError();
  if (!selectedLot) return;
  const postUrlEl = document.getElementById('post-url');
  const postUrl = (postUrlEl && postUrlEl.value || '').trim();
  if (!postUrl) {
    showShareError(t('bid.invalidShareUrl'));
    return;
  }
  if (postUrl.includes('share.php')) {
    showShareError(t('bid.shareIsNotPost'));
    return;
  }
  const amountUsd = bidInputToUsd(bidAmount.value);
  const lotId = Number(selectedLot.dataset.lotId);
  confirmBidBtn.disabled = true;
  confirmBidBtn.dataset.original = confirmBidBtn.innerHTML;
  confirmBidBtn.innerHTML = '<iconify-icon icon="lucide:loader-2"></iconify-icon> ' + t('common.loading');
  pendingBidPayload = { lot_id: lotId, amount_usd: Number(amountUsd.toFixed(2)), share_url: postUrl };
  try {
    const resp = await submitBid(pendingBidPayload);
    if (resp.status === 401) {
      window.location.href = '/auth/login';
      return;
    }
    const data = await resp.json().catch(() => ({}));
    if (resp.status === 202 && data.otp_required) {
      const otpBlock = document.getElementById('otp-block');
      const otpHint = document.getElementById('otp-demo-hint');
      const otpInput = document.getElementById('otp-input');
      if (otpBlock) otpBlock.classList.remove('hidden');
      if (otpHint && data.demo_code) otpHint.textContent = '(Демо-код: ' + data.demo_code + ')';
      if (otpInput) { otpInput.value = ''; otpInput.focus(); }
      confirmBidBtn.disabled = true;
      confirmBidBtn.innerHTML = confirmBidBtn.dataset.original;
      return;
    }
    if (!resp.ok) {
      const messages = {
        invalid_share_url: t('bid.invalidShareUrl'),
        amount_too_low: t('bid.tooLow') + ': $' + (data.minimum_usd || 0).toFixed(2),
        duplicate_bid: t('bid.duplicate'),
        lot_ended: t('bid.lotEnded'),
        lot_not_active: t('bid.notActive'),
        own_lot: 'Нельзя ставить ставку на собственный лот',
        insufficient_balance: data.message || ('Недостаточно средств. Баланс $' + (data.balance_usd || 0).toFixed(2) + ', нужно $' + (data.required_usd || 0).toFixed(2)),
      };
      showShareError(messages[data.error] || data.message || ('Ошибка: ' + (data.error || resp.status)));
      confirmBidBtn.disabled = false;
      confirmBidBtn.innerHTML = confirmBidBtn.dataset.original;
      return;
    }
    addInstantBidToHistory({
      bid_id: data.bid_id,
      amount_usd: amountUsd,
      username: getCurrentUsername() || 'вы',
      verified: data.share_verified || false,
    });
    showStep(2);
    confirmBidBtn.disabled = false;
    confirmBidBtn.innerHTML = confirmBidBtn.dataset.original;
    if (window.bidstageWaitForBid) window.bidstageWaitForBid(data.bid_id);
  } catch (e) {
    showShareError(t('common.networkError'));
    confirmBidBtn.disabled = false;
    confirmBidBtn.innerHTML = confirmBidBtn.dataset.original;
  }
});

const otpConfirmBtn = document.getElementById('otp-confirm');
if (otpConfirmBtn) otpConfirmBtn.addEventListener('click', async () => {
  showOtpError('');
  const otpInput = document.getElementById('otp-input');
  if (!otpInput || !pendingBidPayload) return;
  const code = (otpInput.value || '').trim();
  if (code.length !== 6 || !/^\d{6}$/.test(code)) {
    showOtpError('Введите 6 цифр');
    return;
  }
  otpConfirmBtn.disabled = true;
  const oldHtml = otpConfirmBtn.innerHTML;
  otpConfirmBtn.innerHTML = '<iconify-icon icon="lucide:loader-2"></iconify-icon> Проверка...';
  try {
    const resp = await submitBid({ ...pendingBidPayload, otp_code: code });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      showOtpError(data.message || data.error || 'Ошибка проверки кода');
      otpConfirmBtn.disabled = false;
      otpConfirmBtn.innerHTML = oldHtml;
      return;
    }
    const otpBlock = document.getElementById('otp-block');
    if (otpBlock) otpBlock.classList.add('hidden');
    addInstantBidToHistory({
      bid_id: data.bid_id,
      amount_usd: pendingBidPayload.amount_usd,
      username: getCurrentUsername() || 'вы',
      verified: data.share_verified || false,
    });
    showStep(2);
    pendingBidPayload = null;
    if (confirmBidBtn) {
      confirmBidBtn.disabled = false;
      confirmBidBtn.innerHTML = confirmBidBtn.dataset.original || 'Подтвердить ставку';
    }
  } catch (e) {
    showOtpError(t('common.networkError'));
    otpConfirmBtn.disabled = false;
    otpConfirmBtn.innerHTML = oldHtml;
  }
});

const otpCancelBtn = document.getElementById('otp-cancel');
if (otpCancelBtn) otpCancelBtn.addEventListener('click', () => {
  const otpBlock = document.getElementById('otp-block');
  if (otpBlock) otpBlock.classList.add('hidden');
  pendingBidPayload = null;
  if (confirmBidBtn) {
    confirmBidBtn.disabled = false;
    confirmBidBtn.innerHTML = confirmBidBtn.dataset.original || 'Подтвердить ставку';
  }
});

function getCurrentUsername() {
  if (document.body && document.body.dataset.currentUser) return document.body.dataset.currentUser;
  return null;
}

function addInstantBidToHistory({ bid_id, amount_usd, username, verified }) {
  if (bid_id && liveBidsAdded.has(bid_id)) return;
  if (bid_id) liveBidsAdded.add(bid_id);
  const history = document.getElementById('bids-history');
  if (history) {
    const empty = history.querySelector('.rounded.border.border-dashed');
    if (empty) empty.remove();
    const item = document.createElement('div');
    item.className = 'flex items-center justify-between gap-4 rounded border border-amber/20 bg-white/[0.02] px-4 py-3 transition';
    item.style.borderColor = 'rgba(240,165,0,0.2)';
    item.style.animation = 'fadeIn 0.4s ease';
    const initials = (username || 'me').slice(0, 2).toUpperCase();
    const time = new Date().toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
    item.innerHTML = `
      <div class="flex items-center gap-3">
        <span class="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-br from-[#7c5cfc] to-[#f0a500] text-xs font-bold text-white">${initials}</span>
        <div>
          <p class="text-sm font-semibold">${username}</p>
          <p class="font-mono text-xs text-muted">${time}</p>
        </div>
      </div>
      <div class="text-right">
        <p class="text-base font-bold">$${amount_usd.toFixed(0)}</p>
        <span class="pill ${verified ? 'pill-success' : 'pill-amber-soft'}" style="font-size:0.6rem;padding:0.15rem 0.4rem;">${verified ? '✓ подтверждена' : '⏳ проверка шары'}</span>
      </div>`;
    history.insertBefore(item, history.firstChild);
  }
  if (typeof window.addFeedItem === 'function') {
    window.addFeedItem('⚡', `<strong>${username}</strong> поставил <strong>$${amount_usd.toFixed(0)}</strong>`, 'bid');
  }
  const total = document.getElementById('stat-total');
  if (total) total.textContent = String(Number(total.textContent || 0) + 1);
}

const closeModalBtn = document.getElementById('close-modal');
if (closeModalBtn) closeModalBtn.addEventListener('click', closeModal);
const successCloseBtn = document.getElementById('success-close');
if (successCloseBtn) successCloseBtn.addEventListener('click', closeModal);
if (modal) {
  modal.addEventListener('click', (event) => {
    if (event.target === modal) closeModal();
  });
}

const shareVkBtn = document.getElementById('share-vk-btn');
if (shareVkBtn) shareVkBtn.addEventListener('click', () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  const title = selectedLot.dataset.name || 'BidStage';
  window.open(`https://vk.com/share.php?url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}&noparse=true`, '_blank', 'width=720,height=560');
});
const shareFbBtn = document.getElementById('share-fb-btn');
if (shareFbBtn) shareFbBtn.addEventListener('click', () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, '_blank', 'width=720,height=560');
});
const shareTwBtn = document.getElementById('share-tw-btn');
if (shareTwBtn) shareTwBtn.addEventListener('click', () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  const title = selectedLot.dataset.name || 'BidStage';
  window.open(`https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(title)}`, '_blank', 'width=720,height=560');
});
const shareTgBtn = document.getElementById('share-tg-btn');
if (shareTgBtn) shareTgBtn.addEventListener('click', () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  const title = selectedLot.dataset.name || 'BidStage';
  window.open(`https://t.me/share/url?url=${encodeURIComponent(url)}&text=${encodeURIComponent(title)}`, '_blank', 'width=720,height=560');
});
const shareWaBtn = document.getElementById('share-wa-btn');
if (shareWaBtn) shareWaBtn.addEventListener('click', () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  const title = selectedLot.dataset.name || 'BidStage';
  window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(title + ' ' + url)}`, '_blank', 'width=720,height=560');
});
const shareCopyBtn = document.getElementById('share-copy-btn');
if (shareCopyBtn) shareCopyBtn.addEventListener('click', async () => {
  if (!selectedLot) return;
  const url = `${window.location.origin}/lot/${selectedLot.dataset.lotId}`;
  try {
    await navigator.clipboard.writeText(url);
    const orig = shareCopyBtn.innerHTML;
    shareCopyBtn.innerHTML = '<iconify-icon icon="lucide:check"></iconify-icon> Скопировано';
    setTimeout(() => { shareCopyBtn.innerHTML = orig; }, 1500);
  } catch (e) {
    if (window.bidstageToast) window.bidstageToast('Не удалось скопировать', 'bad');
  }
});

setCurrency(currentCurrency);
applyLanguage();
updateTimers();
setInterval(updateTimers, 1000);

fetch('/api/rates').then((r) => (r.ok ? r.json() : null)).then((data) => {
  if (!data || !data.AMD) return;
  rates.AMD = Number(data.AMD) || 390;
  rates.RUB = Number(data.RUB) || 90;
  rates.USD = 1;
  updatePrices();
}).catch(() => {});

fetch('/api/online').then((r) => (r.ok ? r.json() : null)).then((data) => {
  if (!data || data.count === undefined) return;
  document.querySelectorAll('[data-online-count]').forEach((el) => { el.textContent = data.count; });
}).catch(() => {});

setInterval(() => {
  fetch('/api/online').then((r) => (r.ok ? r.json() : null)).then((data) => {
    if (!data || data.count === undefined) return;
    document.querySelectorAll('[data-online-count]').forEach((el) => { el.textContent = data.count; });
  }).catch(() => {});
  document.querySelectorAll('[data-lot-viewers]').forEach((el) => {
    const lotId = el.closest('[data-lot-id]')?.dataset?.lotId;
    if (!lotId) return;
    fetch('/api/lot/' + lotId + '/viewers').then((r) => (r.ok ? r.json() : null)).then((data) => {
      if (data && data.count !== undefined) el.textContent = data.count;
    }).catch(() => {});
  });
}, 8000);

const toast = (message, kind) => {
  const node = document.createElement('div');
  const cls = kind === 'good' ? 'toast-good' : kind === 'warn' ? 'toast-warn' : 'toast-bad';
  node.className = `toast ${cls} fixed right-6 z-[200] max-w-sm`;
  node.style.bottom = `${24 + document.querySelectorAll('[data-toast]').length * 64}px`;
  node.dataset.toast = '1';
  node.textContent = message;
  document.body.appendChild(node);
  setTimeout(() => { node.style.opacity = '0'; node.style.transition = 'opacity 0.4s'; }, 5000);
  setTimeout(() => { node.remove(); }, 5500);
};
window.bidstageToast = toast;

const updateLotPriceFromServer = (lotId, amountUsd) => {
  document.querySelectorAll(`[data-lot-id="${lotId}"]`).forEach((card) => {
    const newAmd = Math.round(Number(amountUsd) * (rates.AMD || 390));
    card.dataset.priceAmd = String(newAmd);
    card.dataset.priceUsd = String(amountUsd);
    card.querySelectorAll('.price').forEach((el) => {
      el.textContent = formatMoney(amountUsd, currentCurrency);
      el.classList.add('flash-amber');
      setTimeout(() => el.classList.remove('flash-amber'), 1100);
    });
  });
};

const extendLotTimer = (lotId, newEndIso) => {
  const newMs = new Date(newEndIso).getTime();
  document.querySelectorAll(`[data-lot-id="${lotId}"]`).forEach((card) => {
    card.dataset.targetTime = String(newMs);
    card.dataset.endTs = String(newMs);
  });
  if (typeof window.bidstageMainTimerUpdate === 'function') {
    window.bidstageMainTimerUpdate(newMs);
  }
};

if (typeof io !== 'undefined') {
  try {
    socket = io({ transports: ['websocket', 'polling'] });
    window.socket = socket;
    socket.on('connect', () => {
      document.querySelectorAll('[data-lot-id]').forEach((card) => {
        const lotId = Number(card.dataset.lotId);
        if (lotId) socket.emit('join_lot', { lot_id: lotId });
      });
    });
    socket.on('online_count', (payload) => {
      document.querySelectorAll('[data-online-count]').forEach((el) => {
        if (payload && payload.count !== undefined) el.textContent = payload.count;
      });
    });
    socket.on('lot_viewers', (payload) => {
      if (!payload) return;
      document.querySelectorAll('[data-lot-viewers]').forEach((el) => {
        const targetLotId = el.closest('[data-lot-id]')?.dataset?.lotId;
        if (!targetLotId || Number(targetLotId) === Number(payload.lot_id)) {
          el.textContent = payload.count;
        }
      });
    });
    socket.on('new_bid', (payload) => {
      addInstantBidToHistory({
        bid_id: payload.bid_id,
        amount_usd: Number(payload.amount_usd),
        username: payload.user || payload.username || 'участник',
        verified: false,
      });
      const text = `Новая ставка от ${payload.user}: ${formatMoney(Number(payload.amount_usd), currentCurrency)} (ожидает проверки)`;
      toast(text, 'good');
      if (window.bidstageNotifications && window.bidstageNotifications.pushPersistent) {
        window.bidstageNotifications.pushPersistent({
          id: 'newbid-' + payload.lot_id + '-' + payload.bid_id,
          title: 'Новая ставка по лоту',
          body: text,
          lot_id: payload.lot_id,
        });
      }
    });
    socket.on('bid_verified', (payload) => {
      updateLotPriceFromServer(payload.lot_id, payload.amount_usd);
      const history = document.getElementById('bids-history');
      let foundRow = false;
      if (history) {
        Array.from(history.children).forEach((row) => {
          const amountEl = row.querySelector('.text-right p.text-base');
          if (!amountEl) return;
          const rowAmount = Number((amountEl.textContent || '').replace(/[^\d.]/g, ''));
          if (Math.abs(rowAmount - Number(payload.amount_usd)) < 0.01) {
            foundRow = true;
            const pill = row.querySelector('.pill');
            if (pill) {
              pill.className = 'pill pill-success';
              pill.style.fontSize = '0.6rem';
              pill.style.padding = '0.15rem 0.4rem';
              pill.textContent = '✓ подтверждена';
            }
            row.style.borderColor = 'rgba(255,255,255,0.06)';
          }
        });
      }
      if (!foundRow) {
        // Ставка пришла как verified без предыдущего new_bid — добавляем в историю как подтверждённую
        addInstantBidToHistory({
          bid_id: payload.bid_id,
          amount_usd: Number(payload.amount_usd),
          username: payload.username || 'участник',
          verified: true,
        });
      }
      if (window._pendingBidId && Number(window._pendingBidId) === Number(payload.bid_id)) {
        const step3 = document.getElementById('modal-step-3');
        if (step3) {
          step3.innerHTML = '<div class="mx-auto flex h-20 w-20 items-center justify-center rounded-full" style="background:rgba(0,200,150,0.15);color:var(--success);"><iconify-icon icon="lucide:check-circle-2" class="text-4xl"></iconify-icon></div>' +
            '<h2 class="heading mt-5 text-2xl font-bold text-success">Ставка принята</h2>' +
            '<p class="mt-2 text-sm text-muted">Шара проверена, ставка зачтена. Если её перебьют — придёт уведомление.</p>' +
            '<button type="button" id="success-close" class="btn btn-violet btn-block mt-5">Вернуться к лоту</button>';
          const btn = document.getElementById('success-close');
          if (btn) btn.addEventListener('click', () => { try { closeModal(); } catch(e){} window.location.reload(); });
        }
        window._pendingBidId = null;
      }
    });
    socket.on('timer_extended', (payload) => {
      extendLotTimer(payload.lot_id, payload.new_end_time);
      toast(`Таймер продлён на лоте #${payload.lot_id}: +${payload.extension_seconds} сек`, 'good');
    });
    socket.on('auction_ended', (payload) => {
      toast(`Лот #${payload.lot_id} завершён.`, 'warn');
    });
    socket.on('new_top_bid', (payload) => {
      updateLotPriceFromServer(payload.lot_id, payload.amount_usd);
    });
    socket.on('outbid', (payload) => {
      const text = `Вашу ставку перебили: ${formatMoney(Number(payload.new_amount_usd), currentCurrency)}`;
      toast(text, 'bad');
      if (window.bidstageNotifications && window.bidstageNotifications.pushPersistent) {
        window.bidstageNotifications.pushPersistent({
          id: 'outbid-' + payload.lot_id + '-' + Date.now(),
          title: '⚠️ Вашу ставку перебили',
          body: text + '. Откройте лот, чтобы увеличить ставку или включить автоставку.',
          lot_id: payload.lot_id,
        });
      }
    });
    socket.on('bid_cancelled', (payload) => {
      const reasons = {
        link_missing: 'в посте нет ссылки на лот',
        post_not_found: 'пост не найден или удалён',
        invalid_share_url: 'ссылка не на пост',
        wall_closed: 'стена/группа закрыта',
        verification_failed: 'не удалось проверить пост',
      };
      const text = reasons[payload.reason] || payload.reason || 'неизвестная причина';
      toast(`Ставка #${payload.bid_id} отклонена: ${text}. Подробности — в уведомлениях.`, 'bad');
      if (window._pendingBidId && Number(window._pendingBidId) === Number(payload.bid_id)) {
        const step3 = document.getElementById('modal-step-3');
        if (step3) {
          step3.innerHTML = '<div class="mx-auto flex h-20 w-20 items-center justify-center rounded-full" style="background:rgba(255,77,109,0.18);color:var(--danger);"><iconify-icon icon="lucide:x-circle" class="text-4xl"></iconify-icon></div>' +
            '<h2 class="heading mt-5 text-2xl font-bold" style="color:var(--danger);">Ставка отклонена</h2>' +
            '<p class="mt-2 text-sm text-muted">' + text + '. Деньги не списаны. Опубликуйте пост со ссылкой на лот и попробуйте снова.</p>' +
            '<button type="button" id="success-close" class="btn btn-violet btn-block mt-5">Закрыть</button>';
          const btn = document.getElementById('success-close');
          if (btn) btn.addEventListener('click', () => { try { closeModal(); } catch(e){} });
        }
        window._pendingBidId = null;
      }
    });
    socket.on('payment_due', (payload) => {
      toast(`Вы выиграли лот #${payload.lot_id}! Оплатите ${formatMoney(Number(payload.amount_usd), currentCurrency)} в 24 ч.`, 'good');
    });
    socket.on('payment_completed', (payload) => {
      toast(`Оплата подтверждена. Билет: ${payload.ticket_code}`, 'good');
    });
    socket.on('escrow_released', (payload) => {
      toast(`Эскроу освобождено по лоту "${payload.lot_title}". Зачислено: $${Number(payload.amount_usd).toFixed(2)}`, 'good');
    });
    socket.on('ticket_delivered', (payload) => {
      toast(`Продавец прислал билет по лоту "${payload.lot_title}". Подтвердите получение.`, 'good');
      if (window.bidstageNotifications && window.bidstageNotifications.pushPersistent) {
        window.bidstageNotifications.pushPersistent({
          id: 'ticket-' + payload.payment_id,
          title: '🎫 Продавец отправил билет',
          body: 'Лот «' + payload.lot_title + '».\nКод билета: ' + payload.ticket_code + '\n\nПроверьте билет, и если получили — нажмите «Я получил товар».',
          lot_id: payload.lot_id,
          payment_id: payload.payment_id,
          confirm_delivery: true,
        });
      }
    });
    window.bidstageWaitForBid = function(bidId) {
      window._pendingBidId = bidId;
      setTimeout(() => {
        if (window._pendingBidId !== bidId) return;
        const step3 = document.getElementById('modal-step-3');
        if (step3) {
          step3.innerHTML = '<div class="mx-auto flex h-20 w-20 items-center justify-center rounded-full" style="background:rgba(240,165,0,0.15);color:var(--secondary);"><iconify-icon icon="lucide:clock" class="text-4xl"></iconify-icon></div>' +
            '<h2 class="heading mt-5 text-2xl font-bold" style="color:var(--secondary);">Проверка затянулась</h2>' +
            '<p class="mt-2 text-sm text-muted">Сервер всё ещё проверяет ваш пост. Окно можно закрыть — результат придёт в уведомлениях и в чате с поддержкой.</p>' +
            '<button type="button" id="success-close" class="btn btn-violet btn-block mt-5">Закрыть</button>';
          const btn = document.getElementById('success-close');
          if (btn) btn.addEventListener('click', () => { try { closeModal(); } catch(e){} });
        }
        window._pendingBidId = null;
      }, 90000);
    };
  } catch (e) {
    console.warn('socket init failed', e);
  }
}
