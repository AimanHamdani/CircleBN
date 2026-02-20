<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventRegistration;
use App\Models\Report;
use App\Models\User;
use Illuminate\Contracts\View\View;

class DashboardController extends Controller
{
    public function index(): View
    {
        return view('admin.dashboard', [
            'totalUsers' => User::query()->count(),
            'totalEvents' => Event::query()->count(),
            'openReports' => Report::query()->where('status', 'open')->count(),
            'pendingEvents' => Event::query()->where('status', 'pending')->count(),
        ]);
    }

    public function analytics(): View
    {
        $totalRegistrations = EventRegistration::query()->count();
        $totalRevenue = EventRegistration::query()->sum('amount');
        $dropOffCount = EventRegistration::query()->where('dropped_off', true)->count();
        $checkInCount = EventRegistration::query()->whereNotNull('checked_in_at')->count();

        $dropOffRate = $totalRegistrations > 0 ? round(($dropOffCount / $totalRegistrations) * 100, 2) : 0;
        $checkInRate = $totalRegistrations > 0 ? round(($checkInCount / $totalRegistrations) * 100, 2) : 0;

        $genderDistribution = EventRegistration::query()
            ->selectRaw('gender, COUNT(*) as total')
            ->whereNotNull('gender')
            ->groupBy('gender')
            ->pluck('total', 'gender');

        $ageMin = EventRegistration::query()->whereNotNull('age')->min('age');
        $ageMax = EventRegistration::query()->whereNotNull('age')->max('age');

        return view('admin.analytics', [
            'totalRegistrations' => $totalRegistrations,
            'totalRevenue' => $totalRevenue,
            'genderDistribution' => $genderDistribution,
            'ageRange' => $ageMin && $ageMax ? $ageMin.' - '.$ageMax : 'No age data',
            'dropOffRate' => $dropOffRate,
            'checkInRate' => $checkInRate,
        ]);
    }

    public function users(): View
    {
        return view('admin.users', [
            'users' => User::query()->latest()->paginate(10),
            'reports' => Report::query()->with(['reporter', 'reportedUser'])->latest()->paginate(10),
        ]);
    }

    public function events(): View
    {
        return view('admin.events', [
            'events' => Event::query()->with('organizer')->latest()->paginate(10),
        ]);
    }

    public function reports(): View
    {
        return view('admin.reports', [
            'reports' => Report::query()->with(['reporter', 'reportedUser', 'event'])->latest()->paginate(10),
        ]);
    }

    public function flaggedContent(): View
    {
        return view('admin.flagged-content', [
            'reports' => Report::query()
                ->with(['reporter', 'reportedUser', 'event'])
                ->where('status', 'open')
                ->latest()
                ->paginate(10),
        ]);
    }
}
