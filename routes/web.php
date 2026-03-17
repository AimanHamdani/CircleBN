<?php

use App\Http\Controllers\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Admin\EventReviewController;
use App\Http\Controllers\Admin\UserModerationController;
use App\Http\Controllers\CheckInController;
use App\Http\Controllers\EventController;
use App\Http\Controllers\EventManagementController;
use App\Http\Controllers\EventRegistrationController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
})->name('home');

// Public event listing
Route::get('/events', [EventController::class, 'index'])->name('events.index');
Route::get('/events/create', [EventController::class, 'create'])->middleware('auth')->name('events.create');
Route::post('/events', [EventController::class, 'store'])->middleware('auth')->name('events.store');
Route::get('/events/{event}', [EventController::class, 'show'])->name('events.show');

Route::get('/dashboard', function () {
    $user = auth()->user();
    $upcomingEvents = \App\Models\Event::query()
        ->where('status', 'approved')
        ->where('starts_at', '>', now())
        ->withCount('registrations')
        ->orderBy('starts_at')
        ->limit(6)
        ->get();

    $myRegistrations = \App\Models\EventRegistration::query()
        ->where('user_id', $user->id)
        ->with('event')
        ->orderBy('created_at', 'desc')
        ->limit(5)
        ->get();

    $myEvents = \App\Models\Event::query()
        ->where('user_id', $user->id)
        ->withCount('registrations')
        ->orderBy('created_at', 'desc')
        ->limit(5)
        ->get();

    return view('dashboard', compact('upcomingEvents', 'myRegistrations', 'myEvents'));
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    // Settings
    Route::view('/settings', 'settings.index')->name('settings');

    // Profile (handled by friend)
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markAsRead'])->name('notifications.read');
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllAsRead'])->name('notifications.readAll');

    // Event registration
    Route::get('/events/{event}/register', [EventRegistrationController::class, 'create'])->name('events.register');
    Route::post('/events/{event}/register', [EventRegistrationController::class, 'store'])->name('events.register.store');
    Route::get('/events/{event}/confirmation', [EventRegistrationController::class, 'confirmation'])->name('events.registration.confirmation');
    Route::get('/events/{event}/qr-code', [EventRegistrationController::class, 'qrCode'])->name('events.qr-code');

    // Event management (organizer)
    Route::prefix('manage/events')->name('events.manage.')->group(function () {
        Route::get('/', [EventManagementController::class, 'index'])->name('index');
        Route::get('/{event}', [EventManagementController::class, 'show'])->name('show');
        Route::get('/{event}/edit', [EventManagementController::class, 'edit'])->name('edit');
        Route::put('/{event}', [EventManagementController::class, 'update'])->name('update');
        Route::get('/{event}/registrations', [EventManagementController::class, 'registrations'])->name('registrations');
        Route::get('/{event}/analytics', [EventManagementController::class, 'analytics'])->name('analytics');
        Route::patch('/{event}/close-registration', [EventManagementController::class, 'closeRegistration'])->name('closeRegistration');
        Route::patch('/{event}/open-registration', [EventManagementController::class, 'openRegistration'])->name('openRegistration');
        Route::post('/{event}/announcements', [EventManagementController::class, 'storeAnnouncement'])->name('announcements.store');

        // Check-in
        Route::get('/{event}/checkin', [CheckInController::class, 'index'])->name('checkin');
        Route::post('/{event}/checkin/scan', [CheckInController::class, 'scan'])->name('checkin.scan');
        Route::post('/{event}/checkin/manual', [CheckInController::class, 'manualCheckIn'])->name('checkin.manual');
    });
});

Route::middleware(['auth', 'admin'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', [AdminDashboardController::class, 'index'])->name('dashboard');
    Route::get('/analytics', [AdminDashboardController::class, 'analytics'])->name('analytics');
    Route::get('/users', [AdminDashboardController::class, 'users'])->name('users');
    Route::get('/events', [AdminDashboardController::class, 'events'])->name('events');
    Route::get('/reports', [AdminDashboardController::class, 'reports'])->name('reports');
    Route::get('/flagged-content', [AdminDashboardController::class, 'flaggedContent'])->name('flagged-content');

    Route::post('/events/{event}/review', [EventReviewController::class, 'store'])->name('events.review');
    Route::post('/users/{user}/moderate', [UserModerationController::class, 'store'])->name('users.moderate');
});

require __DIR__.'/auth.php';
