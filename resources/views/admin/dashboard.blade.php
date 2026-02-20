<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 leading-tight">Admin Dashboard</h2>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            @if (session('status'))
                <div class="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg">
                    {{ session('status') }}
                </div>
            @endif

            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
                <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <p class="text-sm text-gray-500">All Users</p>
                    <p class="text-2xl font-semibold text-gray-900 mt-2">{{ $totalUsers }}</p>
                </div>
                <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <p class="text-sm text-gray-500">All Events</p>
                    <p class="text-2xl font-semibold text-gray-900 mt-2">{{ $totalEvents }}</p>
                </div>
                <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <p class="text-sm text-gray-500">Open Reports</p>
                    <p class="text-2xl font-semibold text-gray-900 mt-2">{{ $openReports }}</p>
                </div>
                <div class="bg-white p-6 rounded-lg border border-gray-200">
                    <p class="text-sm text-gray-500">Pending Review</p>
                    <p class="text-2xl font-semibold text-gray-900 mt-2">{{ $pendingEvents }}</p>
                </div>
            </div>

            <div class="bg-white p-6 rounded-lg border border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Admin Views</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    <a href="{{ route('admin.analytics') }}" class="px-4 py-3 border rounded-lg hover:bg-gray-50">Analytics</a>
                    <a href="{{ route('admin.users') }}" class="px-4 py-3 border rounded-lg hover:bg-gray-50">All Users</a>
                    <a href="{{ route('admin.events') }}" class="px-4 py-3 border rounded-lg hover:bg-gray-50">All Events</a>
                    <a href="{{ route('admin.reports') }}" class="px-4 py-3 border rounded-lg hover:bg-gray-50">Reports</a>
                    <a href="{{ route('admin.flagged-content') }}" class="px-4 py-3 border rounded-lg hover:bg-gray-50">Flagged Content</a>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
