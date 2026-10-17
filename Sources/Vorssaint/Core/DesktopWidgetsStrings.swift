// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Words for the cards Vorssaint draws on the desktop and for their settings.
struct DesktopWidgetsFeatureStrings {
    let cardTitle: String
    let cardCaption: String
    let system: String
    let systemCompact: String
    let agenda: String
    let nextEvent: String
    let showTitles: String
    let showTitlesCaption: String
    let resetPositions: String
    let allowCalendar: String
    let noCalendarAccess: String
    let cpu: String
    let memory: String
    let temperature: String
    let network: String
    let disk: String
    let gpu: String
    let pressureNormal: String
    let pressureWarning: String
    let pressureCritical: String
    let average: String
    let nowLabel: String
    let nextLabel: String
    let untilFormat: String
    let noEventsToday: String
    let nothingElseToday: String
    let nothingTomorrow: String
    let tomorrowFormat: String
    let tomorrowCountFormat: String
    let moreFormat: String
    let allDay: String
    let busy: String
}

extension FeatureStrings {
    static func desktopWidgets(_ language: AppLanguage) -> DesktopWidgetsFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension DesktopWidgetsFeatureStrings {
    static let enUS = DesktopWidgetsFeatureStrings(
        cardTitle: "Desktop widgets",
        cardCaption: "Cards Vorssaint draws on your desktop. Drag one to move it; they stay behind your windows.",
        system: "System",
        systemCompact: "System (compact)",
        agenda: "Agenda",
        nextEvent: "Next event",
        showTitles: "Show event titles and places",
        showTitlesCaption: "Off, the widgets only say Busy.",
        resetPositions: "Reset positions",
        allowCalendar: "Allow calendar access",
        noCalendarAccess: "Allow calendar access in Vorssaint",
        cpu: "CPU",
        memory: "Memory",
        temperature: "Temperature",
        network: "Network",
        disk: "Disk",
        gpu: "GPU",
        pressureNormal: "normal",
        pressureWarning: "warning",
        pressureCritical: "critical",
        average: "average",
        nowLabel: "Now",
        nextLabel: "Next",
        untilFormat: "until %@",
        noEventsToday: "No events today",
        nothingElseToday: "Nothing else today",
        nothingTomorrow: "Nothing tomorrow",
        tomorrowFormat: "Tomorrow: %d, first at %@",
        tomorrowCountFormat: "Tomorrow: %d",
        moreFormat: "+%d more",
        allDay: "All day",
        busy: "Busy"
    )

    static let ptBR = DesktopWidgetsFeatureStrings(
        cardTitle: "Widgets na mesa",
        cardCaption: "Cartões que o Vorssaint desenha na sua mesa. Arraste um para movê-lo; eles ficam atrás das suas janelas.",
        system: "Sistema",
        systemCompact: "Sistema (compacto)",
        agenda: "Agenda",
        nextEvent: "Próximo evento",
        showTitles: "Mostrar títulos e locais dos eventos",
        showTitlesCaption: "Desligado, os widgets só dizem Ocupado.",
        resetPositions: "Restaurar posições",
        allowCalendar: "Permitir acesso ao calendário",
        noCalendarAccess: "Permita o acesso ao calendário no Vorssaint",
        cpu: "CPU",
        memory: "Memória",
        temperature: "Temperatura",
        network: "Rede",
        disk: "Disco",
        gpu: "GPU",
        pressureNormal: "normal",
        pressureWarning: "alerta",
        pressureCritical: "crítico",
        average: "média",
        nowLabel: "Agora",
        nextLabel: "Próximo",
        untilFormat: "até %@",
        noEventsToday: "Sem eventos hoje",
        nothingElseToday: "Nada mais hoje",
        nothingTomorrow: "Nada amanhã",
        tomorrowFormat: "Amanhã: %d, o primeiro às %@",
        tomorrowCountFormat: "Amanhã: %d",
        moreFormat: "+%d",
        allDay: "Dia todo",
        busy: "Ocupado"
    )

    static let tr = DesktopWidgetsFeatureStrings(
        cardTitle: "Masaüstü widget’ları",
        cardCaption: "Vorssaint’in masaüstünüze çizdiği kartlar. Taşımak için sürükleyin; pencerelerinizin arkasında kalırlar.",
        system: "Sistem",
        systemCompact: "Sistem (kompakt)",
        agenda: "Ajanda",
        nextEvent: "Sonraki etkinlik",
        showTitles: "Etkinlik başlıklarını ve yerlerini göster",
        showTitlesCaption: "Kapalıyken widget’lar yalnızca Meşgul yazar.",
        resetPositions: "Konumları sıfırla",
        allowCalendar: "Takvim erişimine izin ver",
        noCalendarAccess: "Vorssaint’e takvim erişimi verin",
        cpu: "CPU",
        memory: "Bellek",
        temperature: "Sıcaklık",
        network: "Ağ",
        disk: "Disk",
        gpu: "GPU",
        pressureNormal: "normal",
        pressureWarning: "uyarı",
        pressureCritical: "kritik",
        average: "ortalama",
        nowLabel: "Şimdi",
        nextLabel: "Sıradaki",
        untilFormat: "%@ saatine kadar",
        noEventsToday: "Bugün etkinlik yok",
        nothingElseToday: "Bugün başka bir şey yok",
        nothingTomorrow: "Yarın bir şey yok",
        tomorrowFormat: "Yarın: %d, ilki %@",
        tomorrowCountFormat: "Yarın: %d",
        moreFormat: "+%d daha",
        allDay: "Tüm gün",
        busy: "Meşgul"
    )

    static let ru = DesktopWidgetsFeatureStrings(
        cardTitle: "Виджеты на рабочем столе",
        cardCaption: "Карточки, которые Vorssaint рисует на рабочем столе. Перетащите карточку, чтобы переместить её; они остаются под окнами.",
        system: "Система",
        systemCompact: "Система (компактно)",
        agenda: "Расписание",
        nextEvent: "Следующее событие",
        showTitles: "Показывать названия и места событий",
        showTitlesCaption: "Если выключено, виджеты показывают только «Занят».",
        resetPositions: "Сбросить положение",
        allowCalendar: "Разрешить доступ к календарю",
        noCalendarAccess: "Разрешите Vorssaint доступ к календарю",
        cpu: "ЦП",
        memory: "Память",
        temperature: "Температура",
        network: "Сеть",
        disk: "Диск",
        gpu: "ГП",
        pressureNormal: "норма",
        pressureWarning: "внимание",
        pressureCritical: "критично",
        average: "среднее",
        nowLabel: "Сейчас",
        nextLabel: "Далее",
        untilFormat: "до %@",
        noEventsToday: "Сегодня событий нет",
        nothingElseToday: "Больше ничего на сегодня",
        nothingTomorrow: "На завтра ничего",
        tomorrowFormat: "Завтра: %d, первое в %@",
        tomorrowCountFormat: "Завтра: %d",
        moreFormat: "ещё %d",
        allDay: "Весь день",
        busy: "Занят"
    )

    static let es = DesktopWidgetsFeatureStrings(
        cardTitle: "Widgets de escritorio",
        cardCaption: "Tarjetas que Vorssaint dibuja en tu escritorio. Arrastra una para moverla; se quedan detrás de tus ventanas.",
        system: "Sistema",
        systemCompact: "Sistema (compacto)",
        agenda: "Agenda",
        nextEvent: "Próximo evento",
        showTitles: "Mostrar títulos y lugares de los eventos",
        showTitlesCaption: "Si está desactivado, los widgets solo dicen Ocupado.",
        resetPositions: "Restablecer posiciones",
        allowCalendar: "Permitir acceso al calendario",
        noCalendarAccess: "Permite el acceso al calendario en Vorssaint",
        cpu: "CPU",
        memory: "Memoria",
        temperature: "Temperatura",
        network: "Red",
        disk: "Disco",
        gpu: "GPU",
        pressureNormal: "normal",
        pressureWarning: "aviso",
        pressureCritical: "crítico",
        average: "media",
        nowLabel: "Ahora",
        nextLabel: "Siguiente",
        untilFormat: "hasta las %@",
        noEventsToday: "Sin eventos hoy",
        nothingElseToday: "Nada más hoy",
        nothingTomorrow: "Nada mañana",
        tomorrowFormat: "Mañana: %d, el primero a las %@",
        tomorrowCountFormat: "Mañana: %d",
        moreFormat: "+%d más",
        allDay: "Todo el día",
        busy: "Ocupado"
    )

    static let sk = DesktopWidgetsFeatureStrings(
        cardTitle: "Widgety na ploche",
        cardCaption: "Karty, ktoré Vorssaint kreslí na vašej ploche. Presuniete ich ťahaním; zostávajú za vašimi oknami.",
        system: "Systém",
        systemCompact: "Systém (kompaktne)",
        agenda: "Agenda",
        nextEvent: "Ďalšia udalosť",
        showTitles: "Zobrazovať názvy a miesta udalostí",
        showTitlesCaption: "Keď je vypnuté, widgety hovoria iba Obsadené.",
        resetPositions: "Obnoviť polohy",
        allowCalendar: "Povoliť prístup ku kalendáru",
        noCalendarAccess: "Povoľte Vorssaintu prístup ku kalendáru",
        cpu: "CPU",
        memory: "Pamäť",
        temperature: "Teplota",
        network: "Sieť",
        disk: "Disk",
        gpu: "GPU",
        pressureNormal: "normálny",
        pressureWarning: "varovanie",
        pressureCritical: "kritický",
        average: "priemer",
        nowLabel: "Teraz",
        nextLabel: "Ďalej",
        untilFormat: "do %@",
        noEventsToday: "Dnes žiadne udalosti",
        nothingElseToday: "Dnes už nič",
        nothingTomorrow: "Zajtra nič",
        tomorrowFormat: "Zajtra: %d, prvá o %@",
        tomorrowCountFormat: "Zajtra: %d",
        moreFormat: "+%d ďalších",
        allDay: "Celý deň",
        busy: "Obsadené"
    )

    static let de = DesktopWidgetsFeatureStrings(
        cardTitle: "Desktop-Widgets",
        cardCaption: "Karten, die Vorssaint auf Ihren Schreibtisch zeichnet. Zum Verschieben ziehen; sie bleiben hinter Ihren Fenstern.",
        system: "System",
        systemCompact: "System (kompakt)",
        agenda: "Agenda",
        nextEvent: "Nächster Termin",
        showTitles: "Titel und Orte der Termine anzeigen",
        showTitlesCaption: "Ausgeschaltet zeigen die Widgets nur Beschäftigt.",
        resetPositions: "Positionen zurücksetzen",
        allowCalendar: "Kalenderzugriff erlauben",
        noCalendarAccess: "Erlauben Sie Vorssaint den Kalenderzugriff",
        cpu: "CPU",
        memory: "Speicher",
        temperature: "Temperatur",
        network: "Netzwerk",
        disk: "Festplatte",
        gpu: "GPU",
        pressureNormal: "normal",
        pressureWarning: "Warnung",
        pressureCritical: "kritisch",
        average: "Durchschnitt",
        nowLabel: "Jetzt",
        nextLabel: "Als Nächstes",
        untilFormat: "bis %@",
        noEventsToday: "Heute keine Termine",
        nothingElseToday: "Heute nichts mehr",
        nothingTomorrow: "Morgen nichts",
        tomorrowFormat: "Morgen: %d, der erste um %@",
        tomorrowCountFormat: "Morgen: %d",
        moreFormat: "+%d weitere",
        allDay: "Ganztägig",
        busy: "Beschäftigt"
    )

    static let fr = DesktopWidgetsFeatureStrings(
        cardTitle: "Widgets du bureau",
        cardCaption: "Des cartes que Vorssaint dessine sur votre bureau. Faites glisser une carte pour la déplacer. Elles restent derrière vos fenêtres.",
        system: "Système",
        systemCompact: "Système (compact)",
        agenda: "Agenda",
        nextEvent: "Prochain événement",
        showTitles: "Afficher les titres et lieux des événements",
        showTitlesCaption: "Désactivé, les widgets indiquent seulement Occupé.",
        resetPositions: "Réinitialiser les positions",
        allowCalendar: "Autoriser l’accès au calendrier",
        noCalendarAccess: "Autorisez l’accès au calendrier dans Vorssaint",
        cpu: "CPU",
        memory: "Mémoire",
        temperature: "Température",
        network: "Réseau",
        disk: "Disque",
        gpu: "GPU",
        pressureNormal: "normale",
        pressureWarning: "alerte",
        pressureCritical: "critique",
        average: "moyenne",
        nowLabel: "Maintenant",
        nextLabel: "Suivant",
        untilFormat: "jusqu’à %@",
        noEventsToday: "Aucun événement aujourd’hui",
        nothingElseToday: "Plus rien aujourd’hui",
        nothingTomorrow: "Rien demain",
        tomorrowFormat: "Demain\u{00A0}: %d, le premier à %@",
        tomorrowCountFormat: "Demain\u{00A0}: %d",
        moreFormat: "+%d de plus",
        allDay: "Toute la journée",
        busy: "Occupé"
    )

    static let it = DesktopWidgetsFeatureStrings(
        cardTitle: "Widget sulla scrivania",
        cardCaption: "Schede che Vorssaint disegna sulla scrivania. Trascinane una per spostarla; restano dietro alle finestre.",
        system: "Sistema",
        systemCompact: "Sistema (compatto)",
        agenda: "Agenda",
        nextEvent: "Prossimo evento",
        showTitles: "Mostra titoli e luoghi degli eventi",
        showTitlesCaption: "Se disattivato, i widget dicono solo Occupato.",
        resetPositions: "Ripristina le posizioni",
        allowCalendar: "Consenti l’accesso al calendario",
        noCalendarAccess: "Consenti a Vorssaint l’accesso al calendario",
        cpu: "CPU",
        memory: "Memoria",
        temperature: "Temperatura",
        network: "Rete",
        disk: "Disco",
        gpu: "GPU",
        pressureNormal: "normale",
        pressureWarning: "avviso",
        pressureCritical: "critica",
        average: "media",
        nowLabel: "Ora",
        nextLabel: "Prossimo",
        untilFormat: "fino alle %@",
        noEventsToday: "Nessun evento oggi",
        nothingElseToday: "Nient’altro oggi",
        nothingTomorrow: "Niente domani",
        tomorrowFormat: "Domani: %d, il primo alle %@",
        tomorrowCountFormat: "Domani: %d",
        moreFormat: "+%d altri",
        allDay: "Tutto il giorno",
        busy: "Occupato"
    )

    static let ja = DesktopWidgetsFeatureStrings(
        cardTitle: "デスクトップウィジェット",
        cardCaption: "Vorssaint がデスクトップに描くカードです。ドラッグで移動できます。ウインドウの背面に表示されます。",
        system: "システム",
        systemCompact: "システム（コンパクト）",
        agenda: "予定",
        nextEvent: "次の予定",
        showTitles: "予定のタイトルと場所を表示",
        showTitlesCaption: "オフにすると、ウィジェットには予定ありとだけ表示されます。",
        resetPositions: "位置をリセット",
        allowCalendar: "カレンダーへのアクセスを許可",
        noCalendarAccess: "Vorssaint にカレンダーへのアクセスを許可してください",
        cpu: "CPU",
        memory: "メモリ",
        temperature: "温度",
        network: "ネットワーク",
        disk: "ディスク",
        gpu: "GPU",
        pressureNormal: "正常",
        pressureWarning: "警告",
        pressureCritical: "危険",
        average: "平均",
        nowLabel: "今",
        nextLabel: "次",
        untilFormat: "%@ まで",
        noEventsToday: "今日の予定はありません",
        nothingElseToday: "今日はこれで終わりです",
        nothingTomorrow: "明日の予定はありません",
        tomorrowFormat: "明日：%d 件、最初は %@",
        tomorrowCountFormat: "明日：%d 件",
        moreFormat: "他 %d 件",
        allDay: "終日",
        busy: "予定あり"
    )

    static let ko = DesktopWidgetsFeatureStrings(
        cardTitle: "바탕화면 위젯",
        cardCaption: "Vorssaint가 바탕화면에 그리는 카드입니다. 드래그하여 이동하세요. 창 뒤에 표시됩니다.",
        system: "시스템",
        systemCompact: "시스템(간략)",
        agenda: "일정",
        nextEvent: "다음 일정",
        showTitles: "일정 제목과 장소 표시",
        showTitlesCaption: "끄면 위젯에는 바쁨으로만 표시됩니다.",
        resetPositions: "위치 초기화",
        allowCalendar: "캘린더 접근 허용",
        noCalendarAccess: "Vorssaint에 캘린더 접근을 허용하세요",
        cpu: "CPU",
        memory: "메모리",
        temperature: "온도",
        network: "네트워크",
        disk: "디스크",
        gpu: "GPU",
        pressureNormal: "정상",
        pressureWarning: "주의",
        pressureCritical: "위험",
        average: "평균",
        nowLabel: "지금",
        nextLabel: "다음",
        untilFormat: "%@까지",
        noEventsToday: "오늘 일정 없음",
        nothingElseToday: "오늘 남은 일정 없음",
        nothingTomorrow: "내일 일정 없음",
        tomorrowFormat: "내일: %d개, 첫 일정 %@",
        tomorrowCountFormat: "내일: %d개",
        moreFormat: "외 %d개",
        allDay: "종일",
        busy: "바쁨"
    )

    static let zhHans = DesktopWidgetsFeatureStrings(
        cardTitle: "桌面小组件",
        cardCaption: "由 Vorssaint 绘制在桌面上的卡片。拖动即可移动，它们会显示在窗口后面。",
        system: "系统",
        systemCompact: "系统（紧凑）",
        agenda: "日程",
        nextEvent: "下一个日程",
        showTitles: "显示日程标题和地点",
        showTitlesCaption: "关闭后，小组件只显示“忙碌”。",
        resetPositions: "重置位置",
        allowCalendar: "允许访问日历",
        noCalendarAccess: "请允许 Vorssaint 访问日历",
        cpu: "CPU",
        memory: "内存",
        temperature: "温度",
        network: "网络",
        disk: "磁盘",
        gpu: "GPU",
        pressureNormal: "正常",
        pressureWarning: "警告",
        pressureCritical: "严重",
        average: "平均",
        nowLabel: "现在",
        nextLabel: "接下来",
        untilFormat: "至 %@",
        noEventsToday: "今天没有日程",
        nothingElseToday: "今天没有更多日程",
        nothingTomorrow: "明天没有日程",
        tomorrowFormat: "明天：%d 项，第一项在 %@",
        tomorrowCountFormat: "明天：%d 项",
        moreFormat: "另有 %d 项",
        allDay: "全天",
        busy: "忙碌"
    )

    static let zhTW = DesktopWidgetsFeatureStrings(
        cardTitle: "桌面小工具",
        cardCaption: "由 Vorssaint 繪製在桌面上的卡片。拖曳即可移動，它們會顯示在視窗後面。",
        system: "系統",
        systemCompact: "系統（精簡）",
        agenda: "行程",
        nextEvent: "下一個行程",
        showTitles: "顯示行程標題和地點",
        showTitlesCaption: "關閉後，小工具只會顯示“忙碌”。",
        resetPositions: "重設位置",
        allowCalendar: "允許存取行事曆",
        noCalendarAccess: "請允許 Vorssaint 存取行事曆",
        cpu: "CPU",
        memory: "記憶體",
        temperature: "溫度",
        network: "網路",
        disk: "磁碟",
        gpu: "GPU",
        pressureNormal: "正常",
        pressureWarning: "警告",
        pressureCritical: "嚴重",
        average: "平均",
        nowLabel: "現在",
        nextLabel: "接下來",
        untilFormat: "至 %@",
        noEventsToday: "今天沒有行程",
        nothingElseToday: "今天沒有更多行程",
        nothingTomorrow: "明天沒有行程",
        tomorrowFormat: "明天：%d 項，第一項在 %@",
        tomorrowCountFormat: "明天：%d 項",
        moreFormat: "另有 %d 項",
        allDay: "全天",
        busy: "忙碌"
    )

    static let zhHK = DesktopWidgetsFeatureStrings(
        cardTitle: "桌面小工具",
        cardCaption: "由 Vorssaint 繪製在桌面上的卡片。拖曳即可移動，它們會顯示在視窗後面。",
        system: "系統",
        systemCompact: "系統（精簡）",
        agenda: "行程",
        nextEvent: "下一個行程",
        showTitles: "顯示行程標題及地點",
        showTitlesCaption: "關閉後，小工具只會顯示“忙碌”。",
        resetPositions: "重設位置",
        allowCalendar: "允許存取日曆",
        noCalendarAccess: "請允許 Vorssaint 存取日曆",
        cpu: "CPU",
        memory: "記憶體",
        temperature: "溫度",
        network: "網絡",
        disk: "磁碟",
        gpu: "GPU",
        pressureNormal: "正常",
        pressureWarning: "警告",
        pressureCritical: "嚴重",
        average: "平均",
        nowLabel: "現在",
        nextLabel: "接下來",
        untilFormat: "至 %@",
        noEventsToday: "今天沒有行程",
        nothingElseToday: "今天沒有更多行程",
        nothingTomorrow: "明天沒有行程",
        tomorrowFormat: "明天：%d 項，第一項在 %@",
        tomorrowCountFormat: "明天：%d 項",
        moreFormat: "另有 %d 項",
        allDay: "全天",
        busy: "忙碌"
    )

    static let uk = DesktopWidgetsFeatureStrings(
        cardTitle: "Віджети на робочому столі",
        cardCaption: "Картки, які Vorssaint малює на робочому столі. Перетягніть картку, щоб перемістити її; вони залишаються під вікнами.",
        system: "Система",
        systemCompact: "Система (компактно)",
        agenda: "Розклад",
        nextEvent: "Наступна подія",
        showTitles: "Показувати назви й місця подій",
        showTitlesCaption: "Коли вимкнено, віджети показують лише «Зайнято».",
        resetPositions: "Скинути розташування",
        allowCalendar: "Дозволити доступ до календаря",
        noCalendarAccess: "Дозвольте Vorssaint доступ до календаря",
        cpu: "ЦП",
        memory: "Пам’ять",
        temperature: "Температура",
        network: "Мережа",
        disk: "Диск",
        gpu: "ГП",
        pressureNormal: "норма",
        pressureWarning: "увага",
        pressureCritical: "критично",
        average: "середнє",
        nowLabel: "Зараз",
        nextLabel: "Далі",
        untilFormat: "до %@",
        noEventsToday: "Сьогодні подій немає",
        nothingElseToday: "Більше нічого на сьогодні",
        nothingTomorrow: "На завтра нічого",
        tomorrowFormat: "Завтра: %d, перша о %@",
        tomorrowCountFormat: "Завтра: %d",
        moreFormat: "ще %d",
        allDay: "Увесь день",
        busy: "Зайнято"
    )
}
