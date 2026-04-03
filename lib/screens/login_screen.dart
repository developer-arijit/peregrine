import 'package:flutter/material.dart';
import '../core/auth/auth_service.dart';
import '../api/api_service.dart';
import '../db/database_helper.dart';
import '../core/storage/secure_storage.dart';
import 'app_initialization_screen.dart';

class LoginScreen extends StatelessWidget {

  // prevents multiple login calls
  static bool isLoggingIn = false;

  void login(BuildContext context) async {

    if (isLoggingIn) return;

    isLoggingIn = true;

    bool success = await AuthService.login();

    if (success) {
      final data = await apiCall(endpoint: "/customers");
      if (data != null) {
        await DatabaseHelper.instance.insertOrUpdateApiResponse(data);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AppInitializationScreen()),
        );
      }else{

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("App initialization failed."),
            duration: const Duration(days: 1), // effectively persistent
            action: SnackBarAction(
              label: "Logout",
              onPressed: () async {
                // Call your logout method
                await SecureStorage.logout();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              textColor: Colors.white, // optional, to make it visible
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.portrait) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    "assets/images/peregrine-portal-snake.jpg",
                    width: double.infinity,
                    fit: BoxFit.cover,
                    height: 270,
                  ),
                ),

                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildContent(context)),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Center(child: _buildContent(context)),
                ),

                Expanded(
                  flex: 1,
                  child: Image.asset(
                    "assets/images/peregrine-portal-snake.jpg",
                    fit: BoxFit.cover,
                    height: double.infinity,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {

    return StatefulBuilder(
      builder: (context, setState) {

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const Text(
              "Sign in",
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Colors.lightGreen,
              ),
            ),

            const SizedBox(height: 45),

            Image.asset(
              "assets/images/peregrine.png",
              height: 60,
            ),

            const SizedBox(height: 50),

            ElevatedButton.icon(
              onPressed: isLoggingIn
                  ? null
                  : () async {

                setState(() {
                  isLoggingIn = true;
                });

                bool success = await AuthService.login();

                if (success) {
                  final data = await apiCall(endpoint: "/customers");
                  if (data != null) {
                    await DatabaseHelper.instance.insertOrUpdateApiResponse(data);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => AppInitializationScreen()),
                    );
                  }else{

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("App initialization failed."),
                        duration: const Duration(days: 1), // effectively persistent
                        action: SnackBarAction(
                          label: "Logout",
                          onPressed: () async {
                            // Call your logout method
                            await SecureStorage.logout();

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                            );
                          },
                          textColor: Colors.white, // optional, to make it visible
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },

              icon: isLoggingIn ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Image.asset(
                "assets/images/microsoft-logo.png",
                height: 30,
              ),

              label: Text(
                isLoggingIn ? "Signing in..." : "Sign in with Microsoft",
                style: const TextStyle(fontSize: 17, color: Colors.blueGrey),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}