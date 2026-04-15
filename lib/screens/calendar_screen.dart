import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../models/models.dart';
import '../widgets/theme.dart';

// ─── Day State enum ───────────────────────────────────────────────────────────
enum DayState { delivered, locked, paused, pending, noSub }
class PauseItem {
  final String fromDate;
  final String toDate;
  final String reason;
  final String status;

  PauseItem({
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
  });

  factory PauseItem.fromJson(Map<String, dynamic> json) {
    return PauseItem(
      fromDate: json['fromDate'] ?? '',
      toDate: json['toDate'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
// ─── Mutable CalDay model ─────────────────────────────────────────────────────
class CalDay {
  final int deliveryId; // 0 if no DB record yet
  final String dateKey; // yyyy-MM-dd
  String status;        // PENDING | DELIVERED | PAUSED | MISSED
  int quantityMl;
  final String slot;

  CalDay({
    required this.deliveryId,
    required this.dateKey,
    required this.status,
    required this.quantityMl,
    required this.slot,
  });

  CalDay.fromJson(Map<String, dynamic> j)
      : deliveryId = j['id'] ?? 0,
        dateKey    = j['deliveryDate'] ?? '',
        status     = j['status'] ?? 'PENDING',
        quantityMl = j['quantityMl'] ?? 500,
        slot       = j['deliverySlot'] ?? 'MORNING';

  bool get isDelivered => status == 'DELIVERED';
  bool get isPaused    => status == 'PAUSED';
  bool get isPending   => status == 'PENDING';
  bool get hasBacking  => deliveryId > 0; // has a real DB row
}

// ─── Lock helper — pure function, easy to test ────────────────────────────────
bool dayIsLocked(DateTime d) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date  = DateTime(d.year, d.month, d.day);

  if (date.isBefore(today)) return true;   // past
  if (date == today)        return true;   // today always locked
  // tomorrow locks at 16:00
  if (date == today.add(const Duration(days: 1)) && now.hour >= 16) return true;
  return false;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CalendarScreen extends StatefulWidget {
  final Function(int index)? onNavigate;
  const CalendarScreen({super.key,
  this.onNavigate});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  SubscriptionModel? _sub;
  // Key: "yyyy-MM-dd", value: mutable CalDay.
  // Days NOT in this map have no delivery scheduled yet.
  Map<String, CalDay> _days = {};
  List<PauseItem> _pauses = [];
  bool _loading = true;
  String? _error;

  // ── helpers ─────────────────────────────────────────────────────────────────
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _hasSub => _sub != null;

  // ── data load ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

Future<void> _load() async {
  if (!mounted) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);

    final results = await Future.wait([
      ApiClient.get('/customer/subscription'),
      ApiClient.get('/customer/calendar?from=${_fmt(first)}&to=${_fmt(last)}'),
      ApiClient.get('/customer/pauses'),
    ]);

    if (!mounted) return;

    final subData = results[0]['data'];
    final calList = results[1]['data'] as List? ?? [];
    final pauseList = results[2]['data'] as List? ?? [];

    final newDays = <String, CalDay>{};

    for (final e in calList) {
      final cd = CalDay.fromJson(e as Map<String, dynamic>);
      if (cd.dateKey.isNotEmpty) {
        newDays[cd.dateKey] = cd;
      }
    }

    if (!mounted) return;

    setState(() {
      _sub = subData != null
          ? SubscriptionModel.fromJson(subData as Map<String, dynamic>)
          : null;

      _days = Map<String, CalDay>.from(newDays); // SAFE COPY
      _pauses = pauseList
          .map((e) => PauseItem.fromJson(e as Map<String, dynamic>))
          .toList();

      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _error = e.toString().replaceAll('Exception: ', '');
      _loading = false;
    });
  }
}
  
  
  // ── toggle pause / unpause ───────────────────────────────────────────────────
Future<void> _togglePause(String dateKey, DateTime date) async {
  if (!_hasSub) return;

  final existing = _days[dateKey];

  // 🔥 CHECK FROM PAUSE LIST ALSO
  final isPausedFromList = _pauses.any((p) =>
      dateKey.compareTo(p.fromDate) >= 0 &&
      dateKey.compareTo(p.toDate) <= 0 &&
      p.status == 'APPROVED');

  final isPaused = existing?.isPaused == true || isPausedFromList;

  HapticFeedback.lightImpact();

  try {
    final endpoint = isPaused
        ? '/customer/calendar/unpause-by-date?date=$dateKey'
        : '/customer/calendar/pause-by-date?date=$dateKey';

    await ApiClient.patch(endpoint);

    // 🔥 INSTANT UI UPDATE (no full reload needed)
    setState(() {
      if (existing != null) {
        existing.status = isPaused ? 'PENDING' : 'PAUSED';
      }

      if (!isPaused) {
        // add pause locally
        _pauses.add(PauseItem(
          fromDate: dateKey,
          toDate: dateKey,
          reason: '',
          status: 'APPROVED',
        ));
      } else {
        // remove pause locally
        _pauses.removeWhere((p) =>
            dateKey.compareTo(p.fromDate) >= 0 &&
            dateKey.compareTo(p.toDate) <= 0);
      }
    });

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: kRed,
      ),
    );
  }
}
  
  // ── edit quantity bottom sheet ────────────────────────────────────────────────
  // void _showEditSheet(String dateKey, DateTime date) {
  //   if (!_hasSub) return;

  //   final existing = _days[dateKey];
  //   if (existing == null || existing.deliveryId == 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //       content: Text('No delivery scheduled for this day.'),
  //       backgroundColor: kOrange,
  //     ));
  //     return;
  //   }
  //   if (existing.isDelivered) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
  //       content: Text('Cannot edit a delivered day.'),
  //       backgroundColor: kTextMid,
  //     ));
  //     return;
  //   }

  //   const quantities = [250, 500, 750, 1000, 1500, 2000];
  //   int picked = existing.quantityMl;

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (_) => StatefulBuilder(
  //       builder: (ctx, setSheet) => Container(
  //         decoration: const BoxDecoration(
  //           color: kCard,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //         ),
  //         padding: EdgeInsets.fromLTRB(
  //             20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
  //         child: Column(mainAxisSize: MainAxisSize.min, children: [
  //           // drag handle
  //           Container(width: 40, height: 4,
  //               decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
  //           const SizedBox(height: 18),

  //           // title
  //           Row(children: [
  //             Container(width: 40, height: 40,
  //                 decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(12)),
  //                 child: const Center(child: Text('🥛', style: TextStyle(fontSize: 20)))),
  //             const SizedBox(width: 12),
  //             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  //               Text('Edit Quantity — ${_dateLabel(dateKey)}',
  //                   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
  //               Text('${existing.slot} slot · currently ${existing.quantityMl}ml',
  //                   style: const TextStyle(fontSize: 11, color: kTextMid)),
  //             ]),
  //           ]),
  //           const SizedBox(height: 20),

  //           // quantity options grid
  //           GridView.count(
  //             crossAxisCount: 3,
  //             shrinkWrap: true,
  //             physics: const NeverScrollableScrollPhysics(),
  //             mainAxisSpacing: 10,
  //             crossAxisSpacing: 10,
  //             childAspectRatio: 2.4,
  //             children: quantities.map((ml) {
  //               final sel = picked == ml;
  //               return GestureDetector(
  //                 onTap: () {
  //                   HapticFeedback.selectionClick();
  //                   setSheet(() => picked = ml);
  //                 },
  //                 child: AnimatedContainer(
  //                   duration: const Duration(milliseconds: 150),
  //                   decoration: BoxDecoration(
  //                     color: sel ? kPrimary : kCard,
  //                     borderRadius: BorderRadius.circular(12),
  //                     border: Border.all(color: sel ? kPrimary : kBorder, width: sel ? 2 : 1),
  //                   ),
  //                   child: Center(
  //                     child: Text(
  //                       ml >= 1000 ? '${ml ~/ 1000}L' : '${ml}ml',
  //                       style: TextStyle(
  //                           fontSize: 14, fontWeight: FontWeight.w700,
  //                           color: sel ? Colors.white : kTextMid),
  //                     ),
  //                   ),
  //                 ),
  //               );
  //             }).toList(),
  //           ),
  //           const SizedBox(height: 22),

  //           // action row
  //           Row(children: [
  //             Expanded(
  //               child: OutlinedButton(
  //                 onPressed: () => Navigator.pop(ctx),
  //                 style: OutlinedButton.styleFrom(
  //                     padding: const EdgeInsets.symmetric(vertical: 14),
  //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  //                 child: const Text('Cancel'),
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               flex: 2,
  //               child: ElevatedButton(
  //                 onPressed: () async {
  //                   Navigator.pop(ctx);
  //                   final prev = existing.quantityMl;
  //                   // Optimistic
  //                   setState(() => existing.quantityMl = picked);
  //                   HapticFeedback.mediumImpact();
  //                   try {
  //                     await ApiClient.patch(
  //                         '/customer/calendar/${existing.deliveryId}/quantity?ml=$picked');
  //                     if (mounted) {
  //                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //                         content: Text('Updated to ${picked >= 1000 ? "${picked ~/ 1000}L" : "${picked}ml"} for ${_dateLabel(dateKey)}'),
  //                         backgroundColor: kGreen,
  //                         duration: const Duration(seconds: 2),
  //                       ));
  //                     }
  //                   } catch (e) {
  //                     setState(() => existing.quantityMl = prev);
  //                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(
  //                         SnackBar(content: Text(e.toString()), backgroundColor: kRed));
  //                   }
  //                 },
  //                 style: ElevatedButton.styleFrom(
  //                     backgroundColor: kPrimary, foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 14),
  //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  //                 child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
  //               ),
  //             ),
  //           ]),
  //         ]),
  //       ),
  //     ),
  //   );
  // }

  // ── helpers ──────────────────────────────────────────────────────────────────
  // String _dateLabel(String key) {
  //   if (key.length < 10) return key;
  //   const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  //   final p = key.split('-');
  //   return '${int.tryParse(p[2]) ?? p[2]} ${m[int.tryParse(p[1]) ?? 0]}';
  // }

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final daysInM  = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWd  = DateTime(_month.year, _month.month, 1).weekday % 7; // 0 = Sun

    const mNames = ['','January','February','March','April','May','June',
        'July','August','September','October','November','December'];

    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        // ── header ──────────────────────────────────────────────────────────
        _buildHeader(),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
        else if (_error != null)
          _buildError()
        else
          Expanded(child: RefreshIndicator(
            onRefresh: _load,
            color: kPrimary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                // ── subscription card ──────────────────────────────────────
                _buildSubCard(),
                const SizedBox(height: 20),

                // ── month navigator ────────────────────────────────────────
                _buildMonthNav(mNames),
                const SizedBox(height: 10),

                // ── weekday headers ────────────────────────────────────────
                _buildWeekdayRow(),
                const SizedBox(height: 6),

                // ── day grid ──────────────────────────────────────────────
                _buildGrid(now, firstWd, daysInM),
                const SizedBox(height: 16),

                // ── legend ─────────────────────────────────────────────────
                _buildLegend(),
                const SizedBox(height: 16),

                // ── instructions card ──────────────────────────────────────
                _buildInstructions(),
                const SizedBox(height: 20),

                // ── pause list ────────────────────────────────────────────
                if (_pauses.isNotEmpty) _buildPauseList(),
              ],
            ),
          )),
      ]),
    );
  }

  // ── sub-builders ─────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    color: kPrimary,
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(children: [
        const KAvatar(initials: 'RK'),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Subscription', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
         // Text('Tap = pause/unpause  •  Hold = change quantity', style: TextStyle(fontSize: 10, color: Color(0xFF90CAF9))),
        ])),
        GestureDetector(
          onTap: _load,
          child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18)),
        ),
      ]),
    )),
  );

  Widget _buildError() => Expanded(child: Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 52, color: kTextLight),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!, style: const TextStyle(color: kTextMid, fontSize: 13), textAlign: TextAlign.center)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ],
  )));

  Widget _buildSubCard() {
    if (_sub == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCC80))),
        child: Row(children: const [
          Text('📭', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No Active Subscription', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOrange)),
            SizedBox(height: 4),
            Text('Contact admin to set up your milk delivery subscription.',
                style: TextStyle(fontSize: 11, color: kOrange, height: 1.5)),
          ])),
        ]),
      );
    }

    final map = _days;

final deliveredCount = map.values.where((d) => d.isDelivered).length;
final pausedCount = _pauses.length;
// final pendingCount = map.values.where((d) => d.isPending).length;
    return Container(
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))]),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Container(width: 46, height: 46,
              decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(13)),
              child: const Center(child: Text('🥛', style: TextStyle(fontSize: 24)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_sub!.planName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
            Text('${_sub!.quantityMl}ml/day · ₹${_sub!.pricePerDay.toStringAsFixed(0)}/day',
                style: const TextStyle(fontSize: 11, color: kTextMid)),
            Text('Since ${_sub!.startDate}', style: const TextStyle(fontSize: 10, color: kTextLight)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _sub!.isActive ? kGreenLt : kOrangeLt,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_sub!.isActive ? '● Active' : '● Paused',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _sub!.isActive ? kGreen : kOrange))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statPill('$deliveredCount', 'Delivered', kGreen, kGreenLt, Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _statPill('$pausedCount', 'Paused', kOrange, kOrangeLt, Icons.pause_circle_rounded),
          // const SizedBox(width: 8),
          // _statPill('$pendingCount', 'Pending', kPrimary, kPrimaryLt, Icons.pending_rounded),
        ]),
      ]),
    );
  }

  Widget _statPill(String n, String label, Color color, Color bg, IconData icon) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color), const SizedBox(width: 4),
            Text(n, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ]),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
        ]),
      ));

  Widget _buildMonthNav(List<String> names) => Row(children: [
    // _mBtn(Icons.chevron_left_rounded, () {
    //   setState(() => _month = DateTime(_month.year, _month.month - 1)); _load();
    // }),
    Expanded(child: Center(child: Text(
        '${names[_month.month]} ${_month.year}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)))),
    // _mBtn(Icons.chevron_right_rounded, () {
    //   setState(() => _month = DateTime(_month.year, _month.month + 1)); _load();
    // }),
  ]);

  // Widget _mBtn(IconData ic, VoidCallback fn) => GestureDetector(onTap: fn,
  //   child: Container(width: 36, height: 36,
  //       decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(18)),
  //       child: Icon(ic, color: kPrimary, size: 22)));

  Widget _buildWeekdayRow() => Row(
    children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((d) =>
        Expanded(child: Center(child: Text(d,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTextLight))))).toList(),
  );

Widget _buildGrid(DateTime now, int firstWd, int daysInM) {
  final total = firstWd + daysInM;

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 7,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 0.68,
    ),
    itemCount: total,
    itemBuilder: (_, idx) {
      // Empty leading cells
      if (idx < firstWd) return const SizedBox();

      final dayNum = idx - firstWd + 1;
      final dayDate = DateTime(_month.year, _month.month, dayNum);
      final key = _fmt(dayDate);
      final cd = _days[key]; // may be null

      final locked = dayIsLocked(dayDate);

      // 🔥 NEW: check pause_requests list
      final isPausedFromList = _pauses.any((p) =>
          key.compareTo(p.fromDate) >= 0 &&
          key.compareTo(p.toDate) <= 0 &&
          p.status == 'APPROVED');
      final isToday = dayDate.year == now.year &&
      dayDate.month == now.month &&
      dayDate.day == now.day;

      // ── Determine state (ONLY THIS PART UPDATED) ──
      DayState state;
      if (cd != null && cd.isDelivered) {
        state = DayState.delivered;
      } else if (isToday) {
        state = DayState.pending; // 👈 force blue UI
      }  else if (locked) {
        state = DayState.locked;
      } else if ((cd != null && cd.isPaused) || isPausedFromList) {
        state = DayState.paused;
      } else if (!_hasSub) {
        state = DayState.noSub;
      } else {
        state = DayState.pending;
      }

      final canEdit = _hasSub && !locked && state != DayState.delivered;

      return _DayCell(
        dayNum: dayNum,
        isToday: dayDate.year == now.year &&
            dayDate.month == now.month &&
            dayDate.day == now.day,
        state: state,
        qty: cd?.quantityMl,
        canEdit: canEdit,
        onTap: _hasSub && !locked
            ? () => _togglePause(key, dayDate)
            : null,
        // onLongPress:
        //     canEdit ? () => _showEditSheet(key, dayDate) : null,
      );
    },
  );
}
  Widget _buildLegend() => Wrap(spacing: 14, runSpacing: 8, children: [
    _lgd(kGreenLt, const Color(0xFFA5D6A7), kGreen, '✓ Delivered'),
    _lgd(kPrimaryLt, kPrimary, kPrimary, 'Today (locked)'),
    _lgd(const Color(0xFFFFF8E1), const Color(0xFFFFCC02), const Color(0xFFF9A825), '⏸ Paused'),
    _lgd(const Color(0xFFF0F2F5), const Color(0xFFD0D7DE), kTextLight, '🔒 Locked'),
    _lgd(kCard, kBorder, kTextDark, '🥛 Tap to pause'),
  ]);

  Widget _lgd(Color bg, Color border, Color tc, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 13, height: 13,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3),
                border: Border.all(color: border))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 9, color: tc, fontWeight: FontWeight.w500)),
      ]);

  Widget _buildInstructions() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kPrimaryLt, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: const [
        Icon(Icons.info_rounded, color: kPrimary, size: 16),
        SizedBox(width: 6),
        Text('How to manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
      ]),
      const SizedBox(height: 8),
      _tip('Tap', 'any 🥛 day — pause or resume delivery'),
      // _tip('Hold', 'any editable day — change quantity (250ml – 2L)'),
      _tip('Locked', 'Today, past, and tomorrow after 4 PM cannot be changed'),
    ]),
  );

  Widget _tip(String action, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70,
          child: Text(action, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary))),
      Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, color: kTextMid, height: 1.4))),
    ]),
  );

  Widget _buildPauseList() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const KSectionTitle(title: 'Scheduled Pauses'),
    const SizedBox(height: 10),
    ..._pauses.take(5).map((p) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
        child: Row(children: [
          const Icon(Icons.pause_circle_rounded, color: kOrange, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.fromDate}  →  ${p.toDate}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextDark)),
            if (p.reason.isNotEmpty)
              Text(p.reason, style: const TextStyle(fontSize: 10, color: kTextLight)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: p.status == 'APPROVED' ? kGreenLt : kOrangeLt,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(p.status,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: p.status == 'APPROVED' ? kGreen : kOrange))),
        ]),
      ),
    )),
  ]);
}

// ─── Day Cell — StatefulWidget for animated press feedback ────────────────────
class _DayCell extends StatefulWidget {
  final int dayNum;
  final bool isToday, canEdit;
  final DayState state;
  final int? qty;
  final VoidCallback? onTap;
  // final VoidCallback? onLongPress;

  const _DayCell({
    required this.dayNum,
    required this.isToday,
    required this.state,
    required this.canEdit,
    this.qty,
    this.onTap,
    // this.onLongPress,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // ── visual config per state ──
    late Color bg, borderColor;
    late double borderWidth;
    late Color numColor;
    late Widget centerIcon;

    switch (widget.state) {
      case DayState.delivered:
        bg = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFFA5D6A7);
        borderWidth = 1.5;
        numColor = kGreen;
        centerIcon = Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: kGreen, size: 15),
          if (widget.qty != null)
            Text('${widget.qty}ml',
                style: const TextStyle(fontSize: 6, color: kGreen, fontWeight: FontWeight.w700)),
        ]);
        break;

      case DayState.locked:
        bg = const Color(0xFFF0F2F5);
        borderColor = const Color(0xFFD0D7DE);
        borderWidth = 0.5;
        numColor = const Color(0xFFB0BEC5);
        centerIcon = Icon(
          widget.isToday ? Icons.lock_rounded : Icons.lock_outline_rounded,
          color: const Color(0xFFCFD8DC),
          size: 13,
        );
        break;

      case DayState.paused:
        bg = const Color(0xFFFFF8E1);
        borderColor = const Color(0xFFFFCC02);
        borderWidth = 1.5;
        numColor = const Color(0xFFF57F17);
        centerIcon = Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.pause_circle_rounded, color: Color(0xFFF57F17), size: 15),
          if (widget.qty != null)
            Text('${widget.qty}ml',
                style: const TextStyle(fontSize: 6, color: Color(0xFFF57F17), fontWeight: FontWeight.w700)),
        ]);
        break;

      case DayState.noSub:
        bg = const Color(0xFFFAFAFA);
        borderColor = const Color(0xFFEEEEEE);
        borderWidth = 0.5;
        numColor = kTextLight;
        centerIcon = const SizedBox.shrink();
        break;

      case DayState.pending:
        bg = widget.isToday ? kPrimaryLt : kCard;
        borderColor = widget.isToday ? kPrimary : kBorder;
        borderWidth = widget.isToday ? 2 : 1;
        numColor = kTextDark;
        centerIcon = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🥛', style: TextStyle(fontSize: 12)),
          if (widget.qty != null && widget.qty != 500)
            Text('${widget.qty}ml',
                style: const TextStyle(fontSize: 6, color: kPrimary, fontWeight: FontWeight.w700)),
        ]);
    }

    // press-scale effect
    if (_pressed && widget.canEdit) {
      bg = Color.alphaBlend(Colors.black.withOpacity(0.05), bg);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ← fixes "can't tap" — catches all touches
      onTapDown: (_) { if (widget.canEdit) setState(() => _pressed = true); },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      // onLongPress: () {
      //   setState(() => _pressed = false);
      //   widget.onLongPress?.call();
      // },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: _pressed && widget.canEdit
            ? (Matrix4.identity()..scale(0.92))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: widget.canEdit && !_pressed
              ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${widget.dayNum}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: numColor)),
            const SizedBox(height: 2),
            centerIcon,
          ]),
        ),
      ),
    );
  }
}
