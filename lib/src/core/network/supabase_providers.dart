import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the active Supabase client instance
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provides the Supabase auth client (GoTrueClient)
final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  return ref.watch(supabaseClientProvider).auth;
});

/// Stream of authentication state changes
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseAuthProvider).onAuthStateChange;
});

/// Current authenticated user (if any)
final currentUserProvider = Provider<User?>((ref) {
  // Watch auth state changes to update current user reactively
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseAuthProvider).currentUser;
});

/// Current session (if any)
final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseAuthProvider).currentSession;
});

/// Helper boolean to check if user is signed in
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
