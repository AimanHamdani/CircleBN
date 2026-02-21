<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
            Notifications
        </h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            {{-- Mark All as Read --}}
            @if($notifications->where('read_at', null)->count() > 0)
                <div class="mb-4 flex justify-end">
                    <form method="POST" action="{{ route('notifications.readAll') }}">
                        @csrf
                        <button type="submit" class="text-sm text-indigo-600 dark:text-indigo-400 hover:underline">
                            Mark all as read
                        </button>
                    </form>
                </div>
            @endif

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg overflow-hidden">
                @forelse($notifications as $notification)
                    <div class="flex items-start gap-4 p-5 border-b border-gray-100 dark:border-gray-700 last:border-0 {{ $notification->read_at ? '' : 'bg-indigo-50/50 dark:bg-indigo-900/10' }}">
                        {{-- Icon --}}
                        <div class="w-10 h-10 rounded-full flex items-center justify-center shrink-0
                            {{ $notification->read_at ? 'bg-gray-100 dark:bg-gray-700' : 'bg-indigo-100 dark:bg-indigo-900/50' }}">
                            @if(str_contains($notification->type ?? '', 'Event'))
                                <svg class="w-5 h-5 {{ $notification->read_at ? 'text-gray-400' : 'text-indigo-600 dark:text-indigo-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                            @else
                                <svg class="w-5 h-5 {{ $notification->read_at ? 'text-gray-400' : 'text-indigo-600 dark:text-indigo-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>
                            @endif
                        </div>

                        {{-- Content --}}
                        <div class="flex-1 min-w-0">
                            <p class="text-sm text-gray-900 dark:text-gray-100 {{ $notification->read_at ? '' : 'font-medium' }}">
                                {{ $notification->data['message'] ?? $notification->data['title'] ?? 'Notification' }}
                            </p>
                            @if(!empty($notification->data['body']))
                                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">{{ $notification->data['body'] }}</p>
                            @endif
                            <p class="text-xs text-gray-400 dark:text-gray-500 mt-1">{{ $notification->created_at->diffForHumans() }}</p>
                        </div>

                        {{-- Mark as Read --}}
                        @if(!$notification->read_at)
                            <form method="POST" action="{{ route('notifications.read', $notification->id) }}">
                                @csrf
                                <button type="submit" class="text-xs text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition" title="Mark as read">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                                </button>
                            </form>
                        @endif
                    </div>
                @empty
                    <div class="p-12 text-center">
                        <svg class="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>
                        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">No notifications</h3>
                        <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">You're all caught up!</p>
                    </div>
                @endforelse
            </div>

            <div class="mt-4">
                {{ $notifications->links() }}
            </div>
        </div>
    </div>
</x-app-layout>
