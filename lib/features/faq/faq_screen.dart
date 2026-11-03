import 'package:customer_app/app/router/routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Bookings & Deliveries',
    'Pricing & Billing',
    'Cancellations & Refunds',
    'Goods & Safety',
    'Claims & Protection',
  ];

  final List<_FaqItem> _allFaqs = [
    // Bookings & Deliveries
    _FaqItem(
      category: 'Bookings & Deliveries',
      question: 'How do I book a delivery on Raftar Gaddi?',
      answer:
          '1. Choose your pickup and drop location on the home screen.\n'
          '2. Select the right vehicle for your load size (Bike, 3-Wheeler, Tata Ace, Pickup, or Truck).\n'
          '3. Review the transparent upfront fare breakdown.\n'
          '4. Confirm the booking. Our system instantly broadcasts your ride to the closest verified drivers within 10-25 km using high-speed geofencing.',
    ),
    _FaqItem(
      category: 'Bookings & Deliveries',
      question: 'What vehicles are available and what are their payload capacities?',
      answer:
          '• 2-Wheeler (Bike): Up to 20 kg (documents, small boxes, food, medicine)\n'
          '• 3-Wheeler (Auto/Piaggio): Up to 500 kg (appliances, retail parcels, small furniture)\n'
          '• Tata Ace / Dost: Up to 750 kg (furniture, heavy home appliances, industrial items)\n'
          '• 8ft Pickup (Bolero): Up to 1,200 kg (commercial freight, construction supplies)\n'
          '• 14ft Truck: Up to 2,500 kg (large consignments, factory goods, full room moves)',
    ),
    _FaqItem(
      category: 'Bookings & Deliveries',
      question: 'How does live parcel tracking work?',
      answer:
          'Once a driver accepts your trip and starts the journey, you receive live GPS updates directly on the map screen in real time via WebSockets. You will also see driver speed, estimated arrival time, and turn-by-turn trip progress.',
    ),
    _FaqItem(
      category: 'Bookings & Deliveries',
      question: 'Can I share the live tracking link with my recipient?',
      answer:
          'Yes! On the live tracking screen, tap the "Share Tracking" button to send an SMS or WhatsApp link to the receiver so they can track the arrival without needing the app.',
    ),

    // Pricing & Billing
    _FaqItem(
      category: 'Pricing & Billing',
      question: 'How are delivery fares calculated?',
      answer:
          'Fares are calculated fairly and transparently based on:\n'
          '• Base fare (minimum distance & vehicle category)\n'
          '• Distance rate per kilometer\n'
          '• Loading and unloading wait time (if applicable)\n'
          '• Applicable highway tolls, state taxes, and GST.\n\n'
          'No hidden costs are charged. The fare estimated at checkout is the fare you pay.',
    ),
    _FaqItem(
      category: 'Pricing & Billing',
      question: 'What payment methods are supported?',
      answer:
          'We accept UPI (Google Pay, PhonePe, Paytm, BHIM), Credit/Debit cards, Net Banking, Raftar Wallet, and Cash on Delivery (Pay at Pickup or Pay at Drop).',
    ),
    _FaqItem(
      category: 'Pricing & Billing',
      question: 'How can I get a GST business invoice?',
      answer:
          'You can add your company GSTIN under Profile -> Business Details. For any completed ride, open the booking receipt from the Bookings tab and tap "Download GST Invoice".',
    ),

    // Cancellations & Refunds
    _FaqItem(
      category: 'Cancellations & Refunds',
      question: 'Can I cancel my ride without any charge?',
      answer:
          'Yes, you can cancel without any cancellation fee within 3 minutes of a driver accepting your order, or at any time before a driver has been assigned. If cancelled after 3 minutes when the driver is en route, a nominal cancellation fee (₹40–₹100 depending on vehicle) is compensated to the driver for fuel and time.',
    ),
    _FaqItem(
      category: 'Cancellations & Refunds',
      question: 'How long do online payment refunds take?',
      answer:
          'If you cancel an order that was prepaid via UPI or card, the refund is initiated immediately. For UPI and Raftar Wallet, it is credited within 1-2 hours. For debit/credit cards, it typically reflects in your bank statement within 3 to 5 business days.',
    ),
    _FaqItem(
      category: 'Cancellations & Refunds',
      question: 'What happens if the assigned driver cancels or is delayed?',
      answer:
          'If a driver cancels or is delayed beyond 15 minutes, our dispatch engine automatically reassigns the nearest available vehicle at no extra charge, or you can cancel with zero fee.',
    ),

    // Goods & Safety
    _FaqItem(
      category: 'Goods & Safety',
      question: 'What goods and materials are strictly prohibited?',
      answer:
          'Strictly prohibited items include:\n'
          '• Explosives, fireworks, flammable liquids, and hazardous chemicals\n'
          '• Weapons, firearms, ammunition, and dangerous sharp weapons\n'
          '• Contraband, narcotics, drugs, and illicit substances\n'
          '• Cash, bullion, unstamped precious gems, and unminted gold\n'
          '• Live animals and livestock\n\n'
          'Drivers reserve the right to inspect packages before loading.',
    ),
    _FaqItem(
      category: 'Goods & Safety',
      question: 'Will the driver assist with loading and unloading?',
      answer:
          'Standard freight delivery includes driver assistance for ground-to-ground loading and unloading for single packages under 25 kg. For heavier goods or upper-floor handling without elevators, please request additional helpers during vehicle selection.',
    ),

    // Claims & Protection
    _FaqItem(
      category: 'Claims & Protection',
      question: 'Is my consignment protected against damage or loss?',
      answer:
          'Yes! Every verified booking on Raftar Gaddi comes with complimentary transit protection coverage up to ₹50,000 for verified commercial and retail merchandise against accidental transit damage or total loss.',
    ),
    _FaqItem(
      category: 'Claims & Protection',
      question: 'How do I submit a transit damage or loss claim?',
      answer:
          '1. Inform our team within 24 hours of delivery.\n'
          '2. Go to Bookings -> Select the trip -> Tap "Need Help / File Claim".\n'
          '3. Connect directly with our live support team in Support Chat and upload parcel photos and the invoice value.\n'
          '4. Claims are processed by our dedicated claims officer within 48 to 72 hours.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqs {
    return _allFaqs.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

    return Scaffold(
      backgroundColor: RaftarColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('FAQs & Guidelines'),
        elevation: 0,
        backgroundColor: RaftarColors.navy,
        foregroundColor: RaftarColors.white,
      ),
      body: Column(
        children: [
          // Header search banner
          Container(
            color: RaftarColors.navy,
            padding: const EdgeInsets.fromLTRB(
              RaftarSpacing.md,
              RaftarSpacing.xs,
              RaftarSpacing.md,
              RaftarSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How can we help you today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: RaftarSpacing.xs),
                const Text(
                  'Find answers to common questions about booking, payments, and safety.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: RaftarSpacing.md),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search questions, policies, or topics...',
                    hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: RaftarColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.black45),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RaftarRadii.lg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Row
          Container(
            color: RaftarColors.surface,
            padding: const EdgeInsets.symmetric(vertical: RaftarSpacing.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RaftarSpacing.md),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : RaftarColors.navy,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      selectedColor: RaftarColors.primary,
                      backgroundColor: RaftarColors.surfaceMuted,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RaftarRadii.pill),
                        side: BorderSide(
                          color: isSelected ? RaftarColors.primary : RaftarColors.border,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(RaftarSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: RaftarSpacing.md),
                          Text(
                            'No answers found for "$_searchQuery"',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: RaftarSpacing.xs),
                          const Text(
                            'Try different keywords or chat with our live support executive.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: RaftarColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: RaftarSpacing.lg),
                          ElevatedButton.icon(
                            onPressed: () => context.push(Routes.supportChat),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RaftarColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(RaftarRadii.pill),
                              ),
                            ),
                            icon: const Icon(Icons.headset_mic_rounded, size: 18),
                            label: const Text('Chat with Support'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(RaftarSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: RaftarSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RaftarRadii.lg),
                          side: const BorderSide(color: RaftarColors.border),
                        ),
                        color: RaftarColors.surface,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: RaftarSpacing.md,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: RaftarColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.help_outline_rounded,
                                color: RaftarColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.question,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: RaftarColors.navy,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: RaftarColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  RaftarSpacing.md,
                                  0,
                                  RaftarSpacing.md,
                                  RaftarSpacing.md,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(RaftarSpacing.md),
                                  decoration: BoxDecoration(
                                    color: RaftarColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(RaftarRadii.md),
                                  ),
                                  child: Text(
                                    item.answer,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: RaftarColors.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Still Have Questions CTA Banner
          Container(
            padding: const EdgeInsets.all(RaftarSpacing.md),
            decoration: BoxDecoration(
              color: RaftarColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: RaftarColors.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: RaftarColors.primary, size: 24),
                  ),
                  const SizedBox(width: RaftarSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Still have questions?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RaftarColors.navy),
                        ),
                        Text(
                          'Chat live with a support executive',
                          style: TextStyle(color: RaftarColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push(Routes.supportChat),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RaftarColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RaftarRadii.pill),
                      ),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text('Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}
