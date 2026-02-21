<?php

use App\Http\Controllers\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Admin\EventReviewController;
use App\Http\Controllers\Admin\UserModerationController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::view('/settings', 'settings.index')->name('settings');
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
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
