import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/background_pattern.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentProfile;
  

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage; // Выбранное и обрезанное фото (локально)
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  late TextEditingController _usernameController;
  late TextEditingController _dobController;
  late TextEditingController _bioController;
  String? _selectedGender;
  DateTime? _selectedDate;
  late TextEditingController _cityController;
  bool _isSearchingCity = false;
  String? _cityError;
  Map<String, double>? _cityCoords; // Здесь будем хранить найденные координаты
  bool _isDetectingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentProfile['username'] ?? '');
    _bioController = TextEditingController(text: widget.currentProfile['bio'] ?? '');
    _selectedGender = widget.currentProfile['gender'];
    _cityController = TextEditingController(text: widget.currentProfile['city'] ?? '');
    // Если координаты уже были сохранены, можно их подтянуть, но мы будем искать заново при сохранении
    
    if (widget.currentProfile['birth_date'] != null) {
      _selectedDate = DateTime.parse(widget.currentProfile['birth_date']);
      _dobController = TextEditingController(text: _formatDate(_selectedDate!));
    } else {
      _dobController = TextEditingController();
    }
        // 🆕 Автоматически определяем геолокацию через небольшую задержку
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectLocation();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _searchCityCoordinatesSilently() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        options: Options(
          headers: {
            'User-Agent': 'TetATetApp/1.0 (support@tet-a-tet.app)',
            'Accept': 'application/json',
          },
        ),
        queryParameters: {
          'q': city,
          'format': 'json',
          'limit': 1,
          'accept-language': 'ru',
        },
      );

      if (response.data.isNotEmpty) {
        final lat = double.parse(response.data[0]['lat']);
        final lon = double.parse(response.data[0]['lon']);
        
        setState(() {
          _cityCoords = {'latitude': lat, 'longitude': lon};
        });
      }
    } catch (e) {
      print('❌ Ошибка поиска координат: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1925),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  // 🆕 Функция выбора и кадрирования аватарки
  Future<void> _pickAndCropAvatar() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      // Открываем экран кадрирования
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0), // 🆕 Строгий квадрат!
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Кадрирование аватарки',
            toolbarColor: const Color(0xFF1E1E1E),
            toolbarWidgetColor: const Color(0xFFD4AF37),
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, // 🆕 Запрещаем менять пропорции
            activeControlsWidgetColor: const Color(0xFFD4AF37),
          ),
          IOSUiSettings(
            title: 'Кадрирование аватарки',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() {
          _selectedImage = File(croppedFile.path);
          _isUploadingAvatar = true;
        });

        // Загружаем на сервер
        final success = await _api.uploadAvatar(File(croppedFile.path));
        
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Аватарка обновлена! 📸'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось загрузить фото'),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _selectedImage = null);
          }
        }
      }
    }
  }
   Future<void> _searchCityCoordinates() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isSearchingCity = true;
      _cityError = null;
      _cityCoords = null;
    });

    try {
      // Создаем отдельный Dio для карт (чтобы не конфликтовал с нашим API)
      final dio = Dio(); 
      
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        options: Options(
          // 🆕 Nominatim требует нормальный User-Agent с email, иначе блокирует!
          headers: {
            'User-Agent': 'TetATetApp/1.0 (support@tet-a-tet.app)',
            'Accept': 'application/json',
          },
        ),
        queryParameters: {
          'q': city,
          'format': 'json',
          'limit': 1,
          'accept-language': 'ru',
        },
      );

      if (response.data.isNotEmpty) {
        final lat = double.parse(response.data[0]['lat']);
        final lon = double.parse(response.data[0]['lon']);
        
        setState(() {
          _cityCoords = {'latitude': lat, 'longitude': lon};
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Координаты для $city найдены! 🌍'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _cityError = 'Город не найден. Попробуйте написать точнее.');
      }
    } on DioException catch (e) {
      //  Ловим именно ошибки Dio, чтобы увидеть статус и ответ сервера
      print(' Ошибка Dio: ${e.response?.statusCode}');
      print('❌ Ответ сервера карт: ${e.response?.data}');
      
      String errorMsg = 'Ошибка сети';
      if (e.response?.statusCode == 403) {
        errorMsg = 'Сервер карт заблокировал запрос. Попробуйте другой город.';
      } else if (e.response?.statusCode == 429) {
        errorMsg = 'Слишком много запросов. Подождите минуту.';
      } else {
        errorMsg = 'Ошибка сервера: ${e.response?.statusCode}';
      }
      setState(() => _cityError = errorMsg);
    } catch (e) {
      print('❌ Общая ошибка: $e');
      setState(() => _cityError = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSearchingCity = false);
    }
  }

  Future<void> _autoDetectLocation() async {
    // Если город уже указан, не перезаписываем
    if (_cityController.text.isNotEmpty) return;

    setState(() {
      _isDetectingLocation = true;
      _locationError = null;
    });

    try {
      // 1. Проверяем разрешение на геолокацию
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Разрешение на геолокацию отклонено');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Разрешение на геолокацию заблокировано');
        return;
      }

      // 2. Получаем текущие координаты
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Не нужна сверхточность
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 3. Reverse geocoding: координаты → город
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality ?? placemarks.first.subAdministrativeArea;
        
        if (city != null && city.isNotEmpty) {
          setState(() {
            _cityController.text = city;
            _cityCoords = {
              'latitude': position.latitude,
              'longitude': position.longitude,
            };
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Город определён: $city 📍'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Ошибка определения геолокации: $e');
      setState(() => _locationError = 'Не удалось определить местоположение');
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем, что показывать: новое выбранное фото или старое из профиля
    final currentAvatarUrl = widget.currentProfile['avatar_url'];
    final isFemale = widget.currentProfile['gender'] == 'female' || widget.currentProfile['gender'] == 'ж';
    final genderIcon = isFemale ? Icons.female : Icons.male;
    final genderColor = isFemale ? const Color(0xFFEC407A) : const Color(0xFF4FC3F7);
    final username = widget.currentProfile['username'] ?? 'Аноним';
    final age = widget.currentProfile['age'];
    final nameWithAge = age != null ? '$username, $age' : username;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.3),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'РЕДАКТИРОВАТЬ',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2))
                      : Text(
                          'СОХРАНИТЬ', 
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFFD4AF37), 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: BackgroundPattern(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            0,
            MediaQuery.of(context).padding.top + kToolbarHeight,
            0,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // 👑 БОЛЬШАЯ АВАТАРКА С КНОПКОЙ КАМЕРЫ
                  Center(
                    child: GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAndCropAvatar,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: _selectedImage != null
                                  ? Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : currentAvatarUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: '${ApiService.baseUrl}$currentAvatarUrl',
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: const Color(0xFF1E1E1E),
                                            child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: const Color(0xFF1E1E1E),
                                            child: const Icon(Icons.person, size: 80, color: Colors.white54),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF1E1E1E),
                                          child: const Icon(Icons.person, size: 80, color: Colors.white54),
                                        ),
                            ),
                            // Градиент снизу с именем
                            Container(
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.95),
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              child: Row(
                                children: [
                                  Icon(genderIcon, color: genderColor, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      nameWithAge,
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 📷 Кнопка камеры в правом нижнем углу
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: _isUploadingAvatar
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // 📝 Поля формы
                  _buildTextField(_usernameController, 'Имя или никнейм', Icons.person),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Дата рождения', 
                    style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Выбери дату',
                      hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                      prefixIcon: const Icon(Icons.cake, color: Color(0xFFD4AF37)),
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                // 🌍 Поле поиска города
                Text(
                  'Город', 
                  style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Например, Москва',
                          hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                          prefixIcon: const Icon(Icons.location_city, color: Color(0xFFD4AF37)),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          errorText: _cityError,
                          errorStyle: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Кнопка поиска
                    SizedBox(
                      height: 56, // Высота как у текстового поля
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: _isSearchingCity ? null : _searchCityCoordinates,
                        child: _isSearchingCity
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Icon(Icons.search, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                  Text(
                    'Пол', 
                    style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Мужской', style: TextStyle(color: Colors.blue))),
                      DropdownMenuItem(value: 'female', child: Text('Женский', style: TextStyle(color: Colors.redAccent))),
                    ],
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                  const SizedBox(height: 24),
              
                  Text(
                    'О себе', 
                    style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 5,
                    maxLength: 500,
                    style: GoogleFonts.montserrat(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Расскажи о себе...',
                      hintStyle: GoogleFonts.montserrat(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.montserrat(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey),
            prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // 🆕 Если город указан, но координаты не найдены (или устарели), ищем заново
    final city = _cityController.text.trim();
    if (city.isNotEmpty && _cityCoords == null) {
      try {
        await _searchCityCoordinatesSilently();
      } catch (e) {
        print('Не удалось найти координаты для города: $e');
      }
    }

    final data = {
      'username': _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
      'birth_date': _selectedDate != null ? _formatDate(_selectedDate!).split('.').reversed.join('-') : null,
      'gender': _selectedGender,
      'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      'city': city.isNotEmpty ? city : null,
      'latitude': _cityCoords?['latitude'],
      'longitude': _cityCoords?['longitude'],      
    };

    final success = await _api.updateProfile(data);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}