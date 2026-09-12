# Notification Protection Rule

Sistem notifikasi FCM di BaknusMail dilindungi oleh aturan ketat:
- Channel ID `channel_email_umum_v4` dan suara `sound_umum` TIDAK BOLEH diubah.
- Berkas `lib/data/services/fcm_service.dart` dan `mailcow-backend/functions/index.js` telah sinkron dengan server produksi (commit `0f471ee`).
- Jika ada tugas atau instruksi yang menyentuh berkas-berkas tersebut, AI WAJIB memberikan peringatan keras kepada pengguna mengenai risiko putusnya koneksi notifikasi dengan server produksi.
