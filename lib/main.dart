import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const OguzKuryeApp());
}

class OguzKuryeApp extends StatelessWidget {
  const OguzKuryeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Oğuz Kurye',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const AnaGezinmeEkrani(),
    );
  }
}

class AnaGezinmeEkrani extends StatefulWidget {
  const AnaGezinmeEkrani({super.key});

  @override
  State<AnaGezinmeEkrani> createState() => _AnaGezinmeEkraniState();
}

class _AnaGezinmeEkraniState extends State<AnaGezinmeEkrani> {
  int _seciliSekme = 0;

  final List<Widget> _sayfalar = [
    const KazancEkrani(),
    const HaritaEkrani(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sayfalar[_seciliSekme],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSekme,
        onTap: (index) => setState(() => _seciliSekme = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Paketler & Kazanç'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Uşak Harita'),
        ],
      ),
    );
  }
}

class PaketModel {
  String paketAdi;
  String odemeTuru;
  bool teslimEdildi;

  PaketModel({required this.paketAdi, required this.odemeTuru, this.teslimEdildi = false});
}

class KazancEkrani extends StatefulWidget {
  const KazancEkrani({super.key});

  @override
  State<KazancEkrani> createState() => _KazancEkraniState();
}

class _KazancEkraniState extends State<KazancEkrani> {
  final yakitController = TextEditingController();
  final double paketUcreti = 45.0;
  
  List<PaketModel> paketler = [];
  String secilenOdeme = 'Nakit';

  void yeniPaketEkle() {
    setState(() {
      int sira = paketler.length + 1;
      paketler.add(PaketModel(paketAdi: 'Paket $sira', odemeTuru: secilenOdeme));
    });
  }

  double get netKazanc {
    int teslimEdilenSayisi = paketler.where((p) => p.teslimEdildi).length;
    double yakit = double.tryParse(yakitController.text) ?? 0.0;
    return (teslimEdilenSayisi * paketUcreti) - yakit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oğuz Kurye - Paket & Kazanç')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: yakitController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: 'Günlük Toplam Yakıt Gideri (TL)', border: OutlineInputBorder()),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Ödeme: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 5),
                DropdownButton<String>(
                  value: secilenOdeme,
                  items: ['Nakit', 'IBAN', 'POS', 'Multinet']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => secilenOdeme = val!),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: yeniPaketEkle,
                  icon: const Icon(Icons.add),
                  label: const Text('Paket Ekle'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: paketler.isEmpty
                  ? const Center(child: Text('Henüz paket eklenmedi. Yukarıdan ekleyebilirsiniz.'))
                  : ListView.builder(
                      itemCount: paketler.length,
                      itemBuilder: (context, index) {
                        final paket = paketler[index];
                        return Card(
                          color: paket.teslimEdildi ? Colors.green.shade50 : Colors.white,
                          child: ListTile(
                            title: Text(paket.paketAdi, style: TextStyle(fontWeight: FontWeight.bold, decoration: paket.teslimEdildi ? TextDecoration.lineThrough : null)),
                            subtitle: Text('Ödeme Türü: ${paket.odemeTuru}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: paket.teslimEdildi ? Colors.grey : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  paket.teslimEdildi = !paket.teslimEdildi;
                                });
                              },
                              child: Text(paket.teslimEdildi ? 'Teslim Edildi' : 'Teslim Et'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.deepOrange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Hesaplanan Net Kazanç', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 5),
                    Text('₺${netKazanc.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800)),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  LatLng usakMerkez = const LatLng(38.6742, 29.4059);
  final MapController _mapController = MapController();

  Future<void> anlikKonumaGit() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LatLng yeniKonum = LatLng(position.latitude, position.longitude);
    
    _mapController.move(yeniKonum, 15.0);
    setState(() {
      usakMerkez = yeniKonum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uşak Canlı Harita')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: usakMerkez,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.oguz.kurye',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: usakMerkez,
                width: 50,
                height: 50,
                child: const Icon(Icons.motorcycle, color: Colors.deepOrange, size: 40),
              ),
            ],
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
