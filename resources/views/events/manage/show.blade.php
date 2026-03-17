<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <div>
                <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">{{ $event->title }}</h2>
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">Event Management Dashboard</p>
            </div>
            <a href="{{ route('events.manage.index') }}" class="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition">&larr; All My Events</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            @if(session('success'))
                <div class="mb-4 p-4 bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-700 rounded-lg text-green-700 dark:text-green-300 text-sm">
                    {{ session('success') }}
                </div>
            @endif

            {{-- Status & Quick Stats --}}
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-5">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</p>
                    @php
                        $statusColors = [
                            'approved' => 'text-green-600 dark:text-green-400',
                            'pending' => 'text-yellow-600 dark:text-yellow-400',
                            'rejected' => 'text-red-600 dark:text-red-400',
                        ];
                    @endphp
                    <p class="text-xl font-bold mt-1 {{ $statusColors[$event->status] ?? 'text-gray-700 dark:text-gray-300' }}">{{ ucfirst($event->status) }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-5">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Registrations</p>
                    <p class="text-xl font-bold text-gray-900 dark:text-gray-100 mt-1">{{ $event->registrations_count }} <span class="text-sm font-normal text-gray-400">{{ $event->capacity ? '/ ' . $event->capacity : '' }}</span></p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-5">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Checked In</p>
                    <p class="text-xl font-bold text-gray-900 dark:text-gray-100 mt-1">{{ $event->registrations->whereNotNull('checked_in_at')->count() }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-5">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Registration</p>
                    <p class="text-xl font-bold mt-1 {{ $event->registration_open ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400' }}">
                        {{ $event->registration_open ? 'Open' : 'Closed' }}
                    </p>
                </div>
            </div>

            {{-- Action Cards --}}
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <a href="{{ route('events.manage.edit', $event) }}" class="group bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 hover:ring-2 hover:ring-indigo-500 transition">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg bg-indigo-100 dark:bg-indigo-900/50 flex items-center justify-center">
                            <svg class="w-5 h-5 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
                        </div>
                        <div>
                            <h3 class="font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition">Edit Event</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">Update event details</p>
                        </div>
                    </div>
                </a>

                <a href="{{ route('events.manage.registrations', $event) }}" class="group bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 hover:ring-2 hover:ring-indigo-500 transition">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg bg-blue-100 dark:bg-blue-900/50 flex items-center justify-center">
                            <svg class="w-5 h-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
                        </div>
                        <div>
                            <h3 class="font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition">View Registrations</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">{{ $event->registrations_count }} participants</p>
                        </div>
                    </div>
                </a>

                <a href="{{ route('events.manage.analytics', $event) }}" class="group bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 hover:ring-2 hover:ring-indigo-500 transition">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg bg-green-100 dark:bg-green-900/50 flex items-center justify-center">
                            <svg class="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
                        </div>
                        <div>
                            <h3 class="font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition">Analytics</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">Stats and insights</p>
                        </div>
                    </div>
                </a>

                <a href="{{ route('events.manage.checkin', $event) }}" class="group bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 hover:ring-2 hover:ring-indigo-500 transition">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg bg-purple-100 dark:bg-purple-900/50 flex items-center justify-center">
                            <svg class="w-5 h-5 text-purple-600 dark:text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/></svg>
                        </div>
                        <div>
                            <h3 class="font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition">Check-in</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">QR scanner for event day</p>
                        </div>
                    </div>
                </a>

                {{-- Toggle Registration --}}
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg {{ $event->registration_open ? 'bg-red-100 dark:bg-red-900/50' : 'bg-green-100 dark:bg-green-900/50' }} flex items-center justify-center">
                            <svg class="w-5 h-5 {{ $event->registration_open ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                @if($event->registration_open)
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                                @else
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"/>
                                @endif
                            </svg>
                        </div>
                        <div class="flex-1">
                            <h3 class="font-medium text-gray-900 dark:text-gray-100">{{ $event->registration_open ? 'Close Registration' : 'Open Registration' }}</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">{{ $event->registration_open ? 'Stop accepting new participants' : 'Accept new participants' }}</p>
                        </div>
                        <form method="POST" action="{{ $event->registration_open ? route('events.manage.closeRegistration', $event) : route('events.manage.openRegistration', $event) }}">
                            @csrf
                            @method('PATCH')
                            <button type="submit" class="px-3 py-1.5 text-xs font-medium rounded-lg {{ $event->registration_open ? 'bg-red-600 text-white hover:bg-red-700' : 'bg-green-600 text-white hover:bg-green-700' }} transition">
                                {{ $event->registration_open ? 'Close' : 'Open' }}
                            </button>
                        </form>
                    </div>
                </div>

                {{-- View Public Page --}}
                <a href="{{ route('events.show', $event) }}" class="group bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6 hover:ring-2 hover:ring-indigo-500 transition">
                    <div class="flex items-center gap-4">
                        <div class="w-10 h-10 rounded-lg bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
                            <svg class="w-5 h-5 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                        </div>
                        <div>
                            <h3 class="font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition">View Public Page</h3>
                            <p class="text-xs text-gray-500 dark:text-gray-400">See what participants see</p>
                        </div>
                    </div>
                </a>
            </div>

            {{-- Announcements Section --}}
            <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg overflow-hidden">
                <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">Announcements</h3>
                </div>

                {{-- Post Announcement Form --}}
                <div class="p-6 border-b border-gray-200 dark:border-gray-700">
                    <form method="POST" action="{{ route('events.manage.announcements.store', $event) }}">
                        @csrf
                        <div class="space-y-3">
                            <input type="text" name="title" placeholder="Announcement title" value="{{ old('title') }}" required
                                class="w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-sm focus:ring-indigo-500 focus:border-indigo-500">
                            @error('title') <p class="text-xs text-red-500">{{ $message }}</p> @enderror

                            <textarea name="body" rows="2" placeholder="Write your announcement..." required
                                class="w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-sm focus:ring-indigo-500 focus:border-indigo-500">{{ old('body') }}</textarea>
                            @error('body') <p class="text-xs text-red-500">{{ $message }}</p> @enderror

                            <div class="flex justify-end">
                                <button type="submit" class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition">Send Announcement</button>
                            </div>
                        </div>
                    </form>
                </div>

                {{-- Announcements List --}}
                <div class="divide-y divide-gray-200 dark:divide-gray-700">
                    @forelse($event->announcements->sortByDesc('created_at') as $announcement)
                        <div class="p-6">
                            <h4 class="font-medium text-gray-900 dark:text-gray-100">{{ $announcement->title }}</h4>
                            <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">{{ $announcement->body }}</p>
                            <p class="text-xs text-gray-400 dark:text-gray-500 mt-2">{{ $announcement->created_at->diffForHumans() }}</p>
                        </div>
                    @empty
                        <div class="p-6 text-center text-sm text-gray-500 dark:text-gray-400">
                            No announcements yet. Post one above to notify your participants.
                        </div>
                    @endforelse
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
