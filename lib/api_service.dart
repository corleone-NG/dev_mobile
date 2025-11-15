import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models.dart';

class ApiService {
  // Remplacez cette URL par l'URL de votre API
  static const String baseUrl = 'https://votre-api.com/api';
  
  /// Envoie un médicament vers l'API
  /// Retourne true si l'envoi a réussi, false sinon
  static Future<bool> sendMedication(Medication medication, {String? imagePath}) async {
    try {
      // Créer une requête multipart pour envoyer les données et l'image
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/medications'),
      );

      // Ajouter les champs de données
      request.fields['id'] = medication.id;
      request.fields['name'] = medication.name;
      request.fields['dose'] = medication.dose;
      request.fields['time'] = jsonEncode(medication.time.toJson());

      // Ajouter l'image si elle existe
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            final imageFile = await http.MultipartFile.fromPath(
              'image',
              imagePath,
            );
            request.files.add(imageFile);
          }
        } catch (e) {
          debugPrint('Erreur lors de l\'ajout de l\'image: $e');
          // Continuer sans l'image si elle ne peut pas être ajoutée
        }
      }

      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Médicament envoyé avec succès à l\'API');
        return true;
      } else {
        debugPrint('Erreur API: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi à l\'API: $e');
      return false;
    }
  }

  /// Alternative: Envoie les données en JSON (sans image)
  static Future<bool> sendMedicationJson(Medication medication) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/medications'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(medication.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Médicament envoyé avec succès à l\'API');
        return true;
      } else {
        debugPrint('Erreur API: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi à l\'API: $e');
      return false;
    }
  }
}

