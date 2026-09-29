import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const OguzKuryeProApp());
}

class OguzKuryeProApp extends StatelessWidget {
  const OguzKuryeProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Oğuz Kurye Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const AnaPanel(),
    );
  }
}

class PaketModel {
  String paketNo;
  String semt;
  double tutar;
  String odemeTuru;
  bool teslimEdildi;
  LatLng konum;

  PaketModel({
    required this.paketNo,
    required this.semt,
    required this.tutar,
    required this.odemeTuru,
    this.teslimEdildi = false,
    required this.konum,
  });
}

class BahsisModel {
  double miktar;
  String tur;
  BahsisModel({required this.miktar, required this.tur});
}

class KuryeMerkezi {
  static List<PaketModel> paketler = [];
  static double bazPaketUcreti = 45.0;
  static double yakitGideri = 0.0;
  static double sigaraYemekGideri = 0.0;
  static double digerMasraflar = 0.0;
  
  static List<BahsisModel> bahsisler = [];
  static List<String> gunlukNotlar = [];

  static bool mesaiAktif = false;
  static int gecenSaniye = 0;
  
  static LatLng? aktifHedefKonum;
  static String aktifHedefIsim = '';

  static int get toplamPaketSayisi => paketler.length;
  static int get teslimEdilenSayisi => paketler.where((p) => p.teslimEdildi).length;

  static double get paketlerdenKazanc => teslimEdilenSayisi * bazPaketUcreti;
  static double get toplamBahsis => bahsisler.fold(0.0, (toplam, b) => toplam + b.miktar);
  static double get toplamCiro => paketlerdenKazanc + toplamBahsis;
  static double get toplamGider => yakitGideri + sigaraYemekGideri + digerMasraflar;
  static double get netKar => toplamCiro - toplamGider;

  static double get nakitToplam {
    double pNakit = paketler.where((p) => p.teslimEdildi && p.odemeTuru == 'Nakit').length * bazPaketUcreti;
    double bNakit = bahsisler.where((b) => b.tur == 'Nakit').fold(0.0, (t, b) => t + b.miktar);
    return pNakit + bNakit;
  }

  static double get dijitalToplam {
    double pDijital = paketler.where((p) => p.teslimEdildi && p.odemeTuru != 'Nakit').length * bazPaketUcreti;
    double bDijital = bahsisler.where((b) => b.tur != 'Nakit').fold(0.0, (t, b) => t + b.miktar);
    return pDijital + bDijital;
  }
}

class AnaPanel extends StatefulWidget {
  const AnaPanel({super.key});

  @override
  State<AnaPanel> createState() => _AnaPanelState();
}

class _AnaPanelState extends State<AnaPanel> {
  int _seciliSekme = 0;

  final List<Widget> _sayfalar = [
    const PaketlerEkrani(),
    const MuhasebeEkrani(),
    const HaritaEkrani(),
    const NotlarEkrani(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sayfalar[_seciliSekme],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSekme,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _seciliSekme = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Paketler'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Kasa & Bilanço'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Harita & Rota'),
          BottomNavigationBarItem(icon: Icon(Icons.note_alt), label: 'Notlar'),
        ],
      ),
    );
  }
}

class PaketlerEkrani extends StatefulWidget {
  const PaketlerEkrani({super.key});

  @override
  State<PaketlerEkrani> createState() => _PaketlerEkraniState();
}

class _PaketlerEkraniState extends State<PaketlerEkrani> {
  final semtController = TextEditingController();
  final bahsisController = TextEditingController();
  String secilenOdeme = 'Nakit';
  String bahsisOdemeTuru = 'Nakit';

  LatLng adresKoordinatBul(String adres) {
    String m = adres.toLowerCase();
    if (m.contains('ismetpaşa') || m.contains('ismet pasa') || m.contains('merkez')) {
      return const LatLng(38.6750, 29.4070);
    } else if (m.contains('atatürk') || m.contains('ataturk')) {
      return const LatLng(38.6800, 29.3950);
    } else if (m.contains('fatih')) {
      return const LatLng(38.6650, 29.4150);
    } else if (m.contains('cumhuriyet')) {
      return const LatLng(38.6700, 29.3900);
    } else if (m.contains('dikilitaş') || m.contains('dikilitas')) {
      return const LatLng(38.6780, 29.3880);
    } else if (m.contains('aybey')) {
      return const LatLng(38.6850, 29.4020);
    } else {
      int sayi = KuryeMerkezi.paketler.length;
      return LatLng(38.6742 + (sayi * 0.002), 29.4059 + (sayi * 0.002));
    }
  }

  void paketEkleModal() {
    semtController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Paket Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: semtController,
              decoration: const InputDecoration(labelText: 'Semt / Adres (örn: İsmetpaşa Mah.)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: secilenOdeme,
              decoration: const InputDecoration(labelText: 'Ödeme Türü', border: OutlineInputBorder()),
              items: ['Nakit', 'IBAN', 'POS', 'Multinet'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => secilenOdeme = val!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () {
              if (semtController.text.isNotEmpty) {
                setState(() {
                  int sira = KuryeMerkezi.paketler.length + 1;
                  LatLng bulunanKonum = adresKoordinatBul(semtController.text);
                  KuryeMerkezi.paketler.add(PaketModel(
                    paketNo: 'Paket #$sira',
                    semt: semtController.text,
                    tutar: KuryeMerkezi.bazPaketUcreti,
                    odemeTuru: secilenOdeme,
                    konum: bulunanKonum,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void bahsisEkleModal() {
    bahsisController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bahşiş Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bahsisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bahşiş Miktarı (TL)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: bahsisOdemeTuru,
              decoration: const InputDecoration(labelText: 'Bahşiş Kanalı', border: OutlineInputBorder()),
              items: ['Nakit', 'IBAN', 'POS'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => bahsisOdemeTuru = val!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              double miktar = double.tryParse(bahsisController.text) ?? 0.0;
              if (miktar > 0) {
                setState(() {
                  KuryeMerkezi.bahsisler.add(BahsisModel(miktar: miktar, tur: bahsisOdemeTuru));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oğuz Kurye Pro - Paketler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'Bahşiş Ekle',
            onPressed: bahsisEkleModal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.deepOrange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Toplam: ${KuryeMerkezi.toplamPaketSayisi}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Teslim: ${KuryeMerkezi.teslimEdilenSayisi}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text('Bahşiş: ₺${KuryeMerkezi.toplamBahsis.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          Expanded(
            child: KuryeMerkezi.paketler.isEmpty
                ? const Center(child: Text('Henüz paket eklenmedi. Sağ alttan ekleyebilirsin.'))
                : ListView.builder(
                    itemCount: KuryeMerkezi.paketler.length,
                    itemBuilder: (context, index) {
                      final p = KuryeMerkezi.paketler[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: p.teslimEdildi ? Colors.green.shade50 : Colors.white,
                        child: ListTile(
                          title: Text('${p.paketNo} - ${p.semt}', style: TextStyle(fontWeight: FontWeight.bold, decoration: p.teslimEdildi ? TextDecoration.lineThrough : null)),
                          subtitle: Text('Ödeme: ${p.odemeTuru} | Ücret: ₺${p.tutar}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.teslimEdildi ? Colors.grey : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                p.teslimEdildi = !p.teslimEdildi;
                              });
                            },
                            child: Text(p.teslimEdildi ? 'Tamamlandı' : 'Teslim Et'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: paketEkleModal,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Paket'),
      ),
    );
  }
}

class MuhasebeEkrani extends StatefulWidget {
  const MuhasebeEkrani({super.key});

  @override
  State<MuhasebeEkrani> createState() => _MuhasebeEkraniState();
}

class _MuhasebeEkraniState extends State<MuhasebeEkrani> {
  final yakitController = TextEditingController(text: KuryeMerkezi.yakitGideri.toString());
  final sigaraYemekController = TextEditingController(text: KuryeMerkezi.sigaraYemekGideri.toString());
  final digerController = TextEditingController(text: KuryeMerkezi.digerMasraflar.toString());

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (KuryeMerkezi.mesaiAktif && _timer == null) {
      _mesaiyiBaslatTimer();
    }
  }

  void _mesaiyiBaslatTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          KuryeMerkezi.gecenSaniye++;
        });
      }
    });
  }

  void mesaiyiToggle() {
    setState(() {
      KuryeMerkezi.mesaiAktif = !KuryeMerkezi.mesaiAktif;
      if (KuryeMerkezi.mesaiAktif) {
        _mesaiyiBaslatTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  String get mesaiSuresiFormatli {
    int saat = KuryeMerkezi.gecenSaniye ~/ 3600;
    int dakika = (KuryeMerkezi.gecenSaniye % 3600) ~/ 60;
    int saniye = KuryeMerkezi.gecenSaniye % 60;
    return '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}:${saniye.toString().padLeft(2, '0')}';
  }

  void giderleriKaydet() {
    setState(() {
      KuryeMerkezi.yakitGideri = double.tryParse(yakitController.text) ?? 0.0;
      KuryeMerkezi.sigaraYemekGideri = double.tryParse(sigaraYemekController.text) ?? 0.0;
      KuryeMerkezi.digerMasraflar = double.tryParse(digerController.text) ?? 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giderler ve kasa güncellendi!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasa, Gider & Mesai')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: KuryeMerkezi.mesaiAktif ? Colors.green.shade50 : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mesai Süresi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(mesaiSuresiFormatli, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KuryeMerkezi.mesaiAktif ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: mesaiyiToggle,
                    child: Text(KuryeMerkezi.mesaiAktif ? 'Mesaiyi Bitir' : 'Mesaiyi Başlat'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: yakitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Benzin / Yakıt Gideri (TL)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sigaraYemekController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sigara & Yemek Gideri (TL)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: digerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tamir / Diğer Masraf (TL)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
            onPressed: giderleriKaydet,
            child: const Text('Giderleri Kaydet', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('GÜNLÜK BİLANÇO ÖZETİ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Toplam Ciro:'),
                    Text('₺${KuryeMerkezi.toplamCiro.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Cüzdandaki Nakit:'),
                    Text('₺${KuryeMerkezi.nakitToplam.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Dijital / IBAN / POS:'),
                    Text('₺${KuryeMerkezi.dijitalToplam.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Toplam Giderler:'),
                    Text('- ₺${KuryeMerkezi.toplamGider.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('NET KALAN KÂR:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₺${KuryeMerkezi.netKar.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HaritaEkrani extends StatefulWidget {
  const HaritaEkrani({super.key});

  @override
  State<HaritaEkrani> createState() => _HaritaEkraniState();
}

class _HaritaEkraniState extends State<HaritaEkrani> {
  LatLng merkezKonum = const LatLng(38.6742, 29.4059);
  final MapController _mapController = MapController();
  final TextEditingController haritaAramaController = TextEditingController();

  Future<void> anlikKonumaGit() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LatLng yeniKonum = LatLng(position.latitude, position.longitude);
    
    _mapController.move(yeniKonum, 15.0);
    setState(() {
      merkezKonum = yeniKonum;
    });
  }

  void adresteAraVeGit(String arananAdres) {
    String m = arananAdres.toLowerCase();
    LatLng hedef;
    if (m.contains('ismetpaşa') || m.contains('ismet pasa')) {
      hedef = const LatLng(38.6750, 29.4070);
    } else if (m.contains('atatürk') || m.contains('ataturk')) {
      hedef = const LatLng(38.6800, 29.3950);
    } else if (m.contains('fatih')) {
      hedef = const LatLng(38.6650, 29.4150);
    } else if (m.contains('cumhuriyet')) {
      hedef = const LatLng(38.6700, 29.3900);
    } else if (m.contains('dikilitaş') || m.contains('dikilitas')) {
      hedef = const LatLng(38.6780, 29.3880);
    } else if (m.contains('aybey')) {
      hedef = const LatLng(38.6850, 29.4020);
    } else {
      hedef = LatLng(merkezKonum.latitude + 0.005, merkezKonum.longitude + 0.005);
    }

    setState(() {
      KuryeMerkezi.aktifHedefKonum = hedef;
      KuryeMerkezi.aktifHedefIsim = arananAdres;
    });

    _mapController.move(hedef, 15.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$aranesAdresi" adresi bulundu, rota çizildi!')),
    );
  }

  List<LatLng> rotaNoktalariUret(LatLng baslangis, LatLng bitis) {
    List<LatLng> noktalar = [];
    int adimSayisi = 20;
    for (int i = 0; i <= adimSayisi; i++) {
      double t = i / adimSayisi;
      double lat = baslangis.latitude + (bitis.latitude - baslangis.latitude) * t;
      double lng = baslangis.longitude + (bitis.longitude - baslangis.longitude) * t;
      noktalar.add(LatLng(lat + (sin(t * pi) * 0.001), lng));
    }
    return noktalar;
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> paketPinleri = KuryeMerkezi.paketler.map((p) {
      return Marker(
        point: p.konum,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () {
            setState(() {
              KuryeMerkezi.aktifHedefKonum = p.konum;
              KuryeMerkezi.aktifHedefIsim = '${p.paketNo} - ${p.semt}';
            });
            _mapController.move(p.konum, 15.0);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Rota Seçildi: ${p.semt}')),
            );
          },
          child: Tooltip(
            message: '${p.paketNo} - ${p.semt}',
            child: Icon(
              Icons.location_pin,
              color: p.teslimEdildi ? Colors.green : Colors.red,
              size: 45,
            ),
          ),
        ),
      );
    }).toList();

    if (KuryeMerkezi.aktifHedefKonum != null) {
      bool paketteVarMi = KuryeMerkezi.paketler.any((p) => p.konum == KuryeMerkezi.aktifHedefKonum);
      if (!paketteVarMi) {
        paketPinleri.add(
          Marker(
            point: KuryeMerkezi.aktifHedefKonum!,
            width: 50,
            height: 50,
            child: const Icon(Icons.location_pin, color: Colors.blue, size: 45),
          ),
        );
      }
    }

    paketPinleri.add(
      Marker(
        point: merkezKonum,
        width: 60,
        height: 60,
        child: const Icon(Icons.motorcycle, color: Colors.deepOrange, size: 45),
      ),
    );

    List<Polyline> rotalar = [];
    if (KuryeMerkezi.aktifHedefKonum != null) {
      rotalar.add(
        Polyline(
          points: rotaNoktalariUret(merkezKonum, KuryeMerkezi.aktifHedefKonum!),
          color: Colors.blueAccent,
          strokeWidth: 5.0,
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: merkezKonum,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.oguz.kurye',
              ),
              PolylineLayer(polylines: rotalar),
              MarkerLayer(markers: paketPinleri),
            ],
          ),
          // Google Maps tarzı üst arama çubuğu
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: haritaAramaController,
                        decoration: const InputDecoration(
                          hintText: 'Adres veya semt ara (örn: Atatürk Mah.)...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            adresteAraVeGit(value);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.deepOrange),
                      onPressed: () {
                        if (haritaAramaController.text.isNotEmpty) {
                          adresteAraVeGit(haritaAramaController.text);
                        }
                      },
                    ),
                    if (KuryeMerkezi.aktifHedefKonum != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            KuryeMerkezi.aktifHedefKonum = null;
                            KuryeMerkezi.aktifHedefIsim = '';
                            haritaAramaController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: anlikKonumaGit,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class NotlarEkrani extends StatefulWidget {
  const NotlarEkrani({super.key});

  @override
  State<NotlarEkrani> createState() => _NotlarEkraniState();
}

class _NotlarEkraniState extends State<NotlarEkrani> {
  final notController = TextEditingController();

  void notEkle() {
    if (notController.text.isNotEmpty) {
      setState(() {
        KuryeMerkezi.gunlukNotlar.add(notController.text);
        notController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notlar & Hatırlatıcılar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: notController,
                    decoration: const InputDecoration(labelText: 'Not yaz (adres tarifi vs.)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: notEkle,
                  child: const Text('Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: KuryeMerkezi.gunlukNotlar.isEmpty
                  ? const Center(child: Text('Henüz not eklenmedi.'))
                  : ListView.builder(
                      itemCount: KuryeMerkezi.gunlukNotlar.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.note, color: Colors.deepOrange),
                            title: Text(KuryeMerkezi.gunlukNotlar[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  KuryeMerkezi.gunlukNotlar.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
